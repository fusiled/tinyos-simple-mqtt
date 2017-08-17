/*******************************************************************************
* NodeC - Node of the network. It collects values from sensors and sends them to
* the PAN coordinator through publish. A node can send and receive messages from
* the PanC iff it has sent a CONNECT message. It can also receive PUBLISH of
* other nodes if it has sent a SUBSCRIBE to the PanC. Confirmation of CONNECT and
* SUBSCRIBE are CONNACK and SUBACK.
*
*
* !!!!!!!!! IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
* The convention is that the PAN coordinator is at address 9. To create a successful
* testing environment it is needed that all the nodes have a different address and a
* different TOS_NODE_ID. THE ASSUMPTIONS ARE:
*
* ADDRESS OF THE NODE: TOS_NODE_ID
* IDENTIFICATION NUMBER OF THE NODE (NODE_ID): TOS_NODE_ID -1
*
* The reason is that in the specification it is said that there can be at most 8 nodes,
* so it is possible to identify nodes only using 3 bits (2^3=8), but the testing environment
* (Cooja) starts to set TOS_NODE_ID=NODE_ADDRESS from 1. If we've used the ids from 1 to 9
* only for the nodes then would be a waste of the TOS_NODE_ID 0 because Cooja does not allow
* the customization of the TOS_NODE_ID.
*
* !!!!!!!!! END OF IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!
*
* The idea is to decouple the logic with tasks. The idea of tasks
* with params is taken by the following resource:
* https://github.com/tinyos/tinyos-main/blob/master/doc/txt/tep106.txt
*
* The possible states of the node are:
*
* NODE_STATE_CONNECTING the node is trying to send a CONNECT, or it's waiting
*   for the CONNACK. This is the initial state of the node
* NODE_STATE_SUBSCRIBING the node is trying to sending a SUBSCRIBE, or it's waiting
*   for the SUBACK. In this state the node can PUBLISH measurements of the sensors
* NODES_STATE_PUBLISHING the node received the SUBACK. Now it must only PUBLISH
*   measurements
*
* qos_mask and topic_mask are bit masks. Bit:
* 0 is associated to TEMPERATURE
* 1 is associated to HUMIDITY
* 2 is associated to LUMINOSITY
*
* qos_mask and topic_mask are fixed for a node given the NODE_ID, but they could
* be changed at runtime in a future extension of the application. qos_mask depends
* on QOS_SEED and the NODE_ID, topic_mask is just the binatry representation of
* the NODE_ID. In this way it is very easy to reproduce different behaviour of the
* nodes in a testing environment.
*
* The node collect measurements in a round-robin fashion. The first measurements
* that a node collect depends on the NODE_ID. the variable sensor_selector chooses
* which measurement take.
*
*
*******************************************************************************/

#include "Commons.h"
#include "printf.h"

#define TEMPERATURE_ID 0
#define HUMIDITY_ID 1
#define LUMINOSITY_ID 2

//Node has to wait CONNECT_TIMEOUT milliseconds until it tries to send
//a new CONNECT
#define CONNECT_TIMEOUT 2048

#define QOS_SEED 157
#define NODE_ID (TOS_NODE_ID - 1 )


//sets timeout triggers for sensor collection
#define SENSOR_BASE_PERIOD 2048
#define SENSOR_TIME_FACTOR 1024
#define SENSOR_PERIOD (SENSOR_BASE_PERIOD+SENSOR_TIME_FACTOR*(7-NODE_ID))


//states of the node
#define NODE_STATE_CONNECTING 0
#define NODE_STATE_SUBSCRIBING 1
#define NODE_STATE_PUBLISHING 2

module NodeC
{
    uses
    {
        interface Boot;
        //task interfaces
        interface TaskSimpleMessage;
        interface PublishTask as SendPublishTask;
        interface PubAckTask as SendPubAckTask;
        //network interfaces
        interface Packet;
        interface AMSend;
        interface SplitControl;
        interface Receive;
        interface PacketAcknowledgements;
	interface ResendModule as ResendBuffer;
        //Sensors
        interface Read<uint16_t> as TemperatureRead;
        interface Read<uint16_t> as HumidityRead;
        interface Read<uint16_t> as LuminosityRead;

        //Timers
        interface Timer<TMilli> as SensorTimer;
        interface Timer<TMilli> as TimeoutTimer;
    }

}
implementation
{
    uint8_t state = NODE_STATE_CONNECTING;
    uint8_t sensor_selector;
    uint8_t topic_mask;
    uint8_t qos_mask;
    uint8_t publish_id=1;
    bool publish_qos;
    message_t pkt;
    message_t pub_pkt;
    message_t puback_pkt;
    message_t resend_pkt;

    //***************** Boot interface ********************//
    //Boot the system
    event void Boot.booted()
    {
        //init fields
        sensor_selector = NODE_ID;
        //topic_mask = NODE_ID;
        topic_mask = 1;
        qos_mask = 1;
        //qos_mask = ( QOS_SEED >> NODE_ID ) & 7;
        //publish_qos tells if we set the qos flag of a PUBLISH to 0 or 1.
        //This could be changed at runtime, but for testing purpose it can
        //be easily set here.
        publish_qos = NODE_ID % 2;
        call SplitControl.start();
    }


    //*********** SplitControl interface ******************//
    event void SplitControl.startDone(error_t err)
    {
        if(err == SUCCESS)
        {
            printf("[Node %u] !READY Connecting to PanCoordinator\n",NODE_ID);
            call TaskSimpleMessage.postTask(CONNECT_CODE,NODE_ID);
        }
        else
        {
            call SplitControl.start();
        }
    }

    event void SplitControl.stopDone(error_t err) {
        /**do nothing*/
    }

    //This task tries to send a SUBSCRIBE to the PAN coordinator
    task void subscribeTask()
    {
        subscribe_msg_t * mess = call Packet.getPayload(&pkt,sizeof(subscribe_msg_t));
        build_subscribe_msg(mess,NODE_ID,topic_mask,qos_mask);
        if(call AMSend.send(PAN_COORDINATOR_ADDRESS,&pkt,sizeof(subscribe_msg_t)) == SUCCESS)
        {
            call TimeoutTimer.startOneShot(CONNECT_TIMEOUT);
            printf("[Node %u] !SUBSCRIBE(%u,%u) received\n",NODE_ID,topic_mask,qos_mask);
        }
    }


    //***************** Message Handlers *****************//
    //create the connect message and try to send it. For the connect there's a lazy
    //approach: if there's somethin wrong, then wait CONNECT_TIMEOUT milliseconds.
    void handle_connect()
    {
        connect_msg_t * mess=call Packet.getPayload(&pkt,sizeof(connect_msg_t));
        build_connect_msg(mess,NODE_ID);
        if(call AMSend.send(PAN_COORDINATOR_ADDRESS,&pkt,sizeof(connect_msg_t)) == SUCCESS)
        {
            printf("[Node %u] CONNECT sent\n",NODE_ID);
        }
        call TimeoutTimer.startOneShot(CONNECT_TIMEOUT);
    }

    //Just notify stdout, change state,begin sensor measurements and try to send
    //the subscribe
    void handle_connack()
    {
        printf("[Node %u] !CONNACK(node:%u) received\n",NODE_ID,NODE_ID);
        state=NODE_STATE_SUBSCRIBING;
        call SensorTimer.startPeriodic( SENSOR_PERIOD );
        post subscribeTask();
    }

    //Just change the state and notify stdout
    void handle_suback()
    {
        state = NODE_STATE_PUBLISHING;
        printf("[Node %u] !SUBACK(node:%u) received\n",NODE_ID,NODE_ID);
    }


    void handle_incoming_publish(publish_msg_t * publish_msg)
    {
        uint8_t publish_topic;
        uint8_t msg_pubid;
        uint16_t pub_payload;
        //send puback back
        publish_topic = (publish_msg->header)>>PUBLISH_TOPIC_ALIGNMENT;
        msg_pubid =  publish_msg->publish_id;
        pub_payload = publish_msg->payload;
        printf("[Node %u] !PUBLISH(node:%u,topic:%u, payload:%u,pid: %u) received\n",NODE_ID,NODE_ID,publish_topic,pub_payload,msg_pubid);
        if ( ((qos_mask>>publish_topic)&1)==1)
        {
            call SendPubAckTask.postTask(NODE_ID,publish_topic,msg_pubid);
        }
    }

    void handle_incoming_puback(puback_msg_t * puback_msg)
    {
        uint8_t msg_pubid;
        msg_pubid = ((uint8_t *)puback_msg)[1];
        printf("[Node %u] !PUBACK(node:%u,pid:%u) received\n",NODE_ID,NODE_ID, msg_pubid);
    }

    //***************** TaskSimpleMessage Interface ********//
    //Decide what to do for this simple message, which measn the shortest ones.
    event void TaskSimpleMessage.runTask(uint8_t code_id, uint8_t node_id)
    {
        switch(code_id)
        {
        case CONNECT_CODE:
            handle_connect();
            break;
        case CONNACK_CODE:
            handle_connack();
            break;
        case SUBACK_CODE:
            handle_suback();
            break;
        default:
            printf("[Node %u] ERROR Cannot switch code_id %u in TaskSimpleMessage.runTask", NODE_ID, code_id);
        }
    }
    //***************** Receive Interface *****************//
    //Get the message and decide what to do observing the type of message
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
    {
        uint8_t chunk;
        uint8_t code_id;
        uint8_t node_id;
        if(len==sizeof(suback_msg_t) || len==sizeof(connect_msg_t)|| len==sizeof(connack_msg_t))
        {
            chunk = *((uint8_t *)payload);
        }
        else if(len==sizeof(subscribe_msg_t) || len==sizeof(puback_msg_t))
        {
            chunk = ((uint8_t *)payload)[1];
        }
        else if(len==sizeof(publish_msg_t))
        {
            publish_msg_t * pub_msg = (publish_msg_t *) payload;
            chunk = pub_msg->header;
        }
        else
        {
            printf("[PanC] ERROR Reception of a wrong size ):\n");
            return msg;
        }
        code_id=chunk & CODE_ID_MASK;
        node_id= (chunk >> GENERAL_NODE_ID_ALIGNMENT) & NODE_ID_MASK;
        printf("[Node %u] INFO received message. code_id: %u, node_id: %u\n", NODE_ID,code_id,node_id);
        switch(code_id)
        {
        case CONNACK_CODE:
        case SUBACK_CODE:
            //Stop the timer as soon as possible
            call TimeoutTimer.stop();
            call TaskSimpleMessage.postTask(code_id,NODE_ID);
            break;
        case PUBLISH_CODE:
            handle_incoming_publish(payload);
            break;
        case PUBACK_CODE:
            handle_incoming_puback(payload);
            break;
        default:
            printf("[Node %u] ERROR invalid code_id %u received",NODE_ID,code_id );
        }
        return msg;
    }

    //*************** AMSend Interface ************************//
    //manage the failure of a sending message.
    event void AMSend.sendDone(message_t* buf,error_t err)
    {
        if(err!=SUCCESS || (state>=NODE_STATE_PUBLISHING && !(call PacketAcknowledgements.wasAcked(buf))) )
        {
            //if fails, try to resend the packet. TODO. use the resend buffer
            if(call AMSend.send(PAN_COORDINATOR_ADDRESS,buf,call Packet.payloadLength(buf)) != SUCCESS)
            {
                //printf("[Node %u] *Resent* Packet\n",NODE_ID);
            }
        }
    }

    //************************* Read interfaces **********************//
    //The structure is the same. Read from the sensor and elide the most signifinant bit
    //to fit the 15 bits of the publish_msg_t payload
    event void TemperatureRead.readDone(error_t result, uint16_t data)
    {
        if(result==SUCCESS)
        {
            //printf("[Node %u] TEM: %u\n", NODE_ID,data);
            call SendPublishTask.postTask(NODE_ID,publish_qos,publish_id,TEMPERATURE_ID, data>>1 );
        }
        else
        {
            printf("[Node %u] TEM: FAIL\n",NODE_ID);
        }

    }

    event void HumidityRead.readDone(error_t result, uint16_t data)
    {
        if(result==SUCCESS)
        {
            call SendPublishTask.postTask(NODE_ID,publish_qos,publish_id,HUMIDITY_ID, data>>1 );
            //printf("[Node %u] HUM: %u\n", NODE_ID,data);
        }
        else
        {
            printf("[Node %u] HUM: FAIL\n",NODE_ID);
        }

    }

    event void LuminosityRead.readDone(error_t result, uint16_t data)
    {
        if(result==SUCCESS)
        {
            call SendPublishTask.postTask(NODE_ID,publish_qos,publish_id,LUMINOSITY_ID, data>>1 );
            //printf("[Node %u] LUM: %u\n", NODE_ID,data);
        }
        else
        {
            printf("[Node %u] LUM: FAIL\n",NODE_ID);
        }
    }

    //Select a sensor. The readDone function triggered by the read command will also call the procedure to
    //create a PUBLISH message.
    event void SensorTimer.fired()
    {
        switch(sensor_selector%3)
        {
        case TEMPERATURE_ID:
            call TemperatureRead.read();
            break;
        case HUMIDITY_ID:
            call HumidityRead.read();
            break;
        case LUMINOSITY_ID:
            call LuminosityRead.read();
            break;
        }
        sensor_selector++;
    }

    //Managet the resend of CONNECT and SUBSCRIBE after the timeout set by CONNECT_TIMEOUT
    event void TimeoutTimer.fired()
    {
        publish_id++;
        switch(state)
        {
        case NODE_STATE_CONNECTING:
            printf("[Node %u] WARN CONNACK not received. Retrying\n",NODE_ID);
            call TaskSimpleMessage.postTask(CONNECT_CODE,NODE_ID);
            break;
        case NODE_STATE_SUBSCRIBING:
            printf("[Node %u] WARN SUBSCRIBE not received. Retrying\n",NODE_ID);
            post subscribeTask();
            break;
        }
    }

    //Send a PUBLISH to the PAN coordinator
    event void SendPublishTask.runTask(uint8_t node_id, uint8_t qos, uint8_t node_publish_id, uint8_t topic, uint16_t payload)
    {
        uint8_t code_check;
        publish_msg_t * mess = call Packet.getPayload(&pub_pkt,sizeof(publish_msg_t));
        build_publish_msg(mess,NODE_ID,qos,node_publish_id,topic,payload);
        code_check=(mess->header) & 7;
        if(code_check!=PUBLISH_CODE)
        {
            printf("[Node %u] ERROR PUBLISH_CODE and code set in publish msg don't match\n",NODE_ID);
        }
        call PacketAcknowledgements.requestAck(&pub_pkt);
        if(call AMSend.send(PAN_COORDINATOR_ADDRESS,&pub_pkt,sizeof(publish_msg_t)) == SUCCESS)
        {
            printf("[Node %u] !PUBLISH(qos:%u,node_pubid:%u,topic:%u,payload:%u) received\n",NODE_ID,qos,node_publish_id,topic,payload);
        }
        else
        {
                 printf("[Node %u] FAILED PUBLISH(qos:%u,node_pubid:%u,topic:%u,payload:%u)\n",NODE_ID,qos,node_publish_id,topic,payload);
                    if( (call ResendBuffer.pushMessage(PAN_COORDINATOR_ADDRESS,pub_pkt,sizeof(publish_msg_t),qos))!=SUCCESS)
                    {
                        printf("[Node %u] ERROR ResendBuffer is full. Discard Packet\n",node_id);
                    }
        }
       
    }

    //Send a PUBACK to the pan coordinator
    event void SendPubAckTask.runTask(uint8_t node_id, uint8_t panc_publish_topic,uint8_t panc_publish_id)
    {
        puback_msg_t * mess = call Packet.getPayload(&puback_pkt,sizeof(puback_msg_t));
	bool sending_qos= (qos_mask >>panc_publish_topic) & 1;
        build_puback_msg(mess,NODE_ID,panc_publish_topic,panc_publish_id);
	
        call PacketAcknowledgements.requestAck(&puback_pkt);
        if(call AMSend.send(PAN_COORDINATOR_ADDRESS,&puback_pkt,sizeof(puback_msg_t)) == SUCCESS)
        {
            printf("[Node %u] PUBACK(publish_id:%u,topic:%u) sent\n",NODE_ID,panc_publish_id,panc_publish_topic);
        }
        else
        {
		
                    printf("[Node %u] FAILED PUBACK(publish_id:%u,topic:%u). qos: %u,\n",node_id,
                           publish_id,panc_publish_topic, sending_qos);
                    if( (call ResendBuffer.pushMessage(PAN_COORDINATOR_ADDRESS,puback_pkt,sizeof(puback_msg_t),sending_qos))!=SUCCESS)
                    {
                        printf("[Node %u] ERROR ResendBuffer is full. Discard Packet\n",node_id);
                    }
        }
    }


   //send the passed message to the specified destination. NOTE: destination is different from node_id!!!
    //We rely on the fact that the address of a node is node_id+1. If we cannot send a packet then it is reinserted back
    //in the queue
    event void ResendBuffer.sendMessage(uint8_t destination, message_t msg, uint8_t payload_size, bool ack_requested)
    {
        //Make this assignment otherwise the mote will crash
        resend_pkt=msg;
        if(ack_requested)
        {
            call PacketAcknowledgements.requestAck(&resend_pkt);
        }
        if(call AMSend.send( destination,&resend_pkt,payload_size) == SUCCESS)
        {
            //printf("[Node %u] Successfully resent message\n",NODE_ID);
        }
        else
        {
            //printf("[Node %u] Error in resent message. Reinserting back into the queue\n",NODE_ID);
            if( (call ResendBuffer.pushMessage(destination,msg,payload_size,ack_requested))!=SUCCESS)
            {
                printf("[Node %u] ERROR ResendBuffer is full. Discard Packet\n",NODE_ID);
            }
        }
    }

}
