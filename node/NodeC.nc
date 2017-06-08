#include "Commons.h"
#include "printf.h"

#ifndef N_NODES
#define N_NODES 8
#endif

#define TEMPERATURE_ID 0
#define HUMIDITY_ID 1
#define LUMINOSITY_ID 2


#define CONNECT_TIMEOUT 2048
#define QOS_SEED 157
#define NODE_ID (TOS_NODE_ID - 1 )

#define SENSOR_BASE_PERIOD 2048
#define SENSOR_TIME_FACTOR 1024
#define SENSOR_PERIOD (SENSOR_BASE_PERIOD+SENSOR_TIME_FACTOR*(7-NODE_ID))

#define NODE_STATE_CONNECTING 0
#define NODE_STATE_SUBSCRIBING 1
#define NODE_STATE_PUBLISHING 2

module NodeC
{
    uses
    {
        interface TaskSimpleMessage;
        interface PublishTask as SendPublishTask;
        interface PubAckTask as SendPubAckTask;
        interface Boot;
        interface AMPacket;
        interface Packet;
        interface AMSend;
        interface SplitControl;
        interface Receive;
	interface PacketAcknowledgements;
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
    message_t pkt;
    uint8_t sensor_selector;
    uint8_t topic_mask;
    uint8_t qos_mask;
    uint8_t publish_id=1;
    bool publish_qos;
    message_t pub_pkt;

    task void subscribeTask();

    //***************** Boot interface ********************//
    event void Boot.booted()
    {
        //init fields
        sensor_selector = NODE_ID;
        //topic_mask = NODE_ID;
        topic_mask = 1;
        qos_mask = 1;
        //qos_mask = ( QOS_SEED >> NODE_ID ) & 7;
        publish_qos = NODE_ID % 2;
        call SplitControl.start();
    }


    //*********** SplitControl interface ******************//
    event void SplitControl.startDone(error_t err)
    {
        if(err == SUCCESS)
        {
            printf("[Node %u] READY! Connecting to PanCoordinator\n",NODE_ID);
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

    //***************** Message Handlers *****************//
    void handle_connect()
    {
        connect_msg_t * mess=call Packet.getPayload(&pkt,sizeof(connect_msg_t));
        build_connect_msg(mess,NODE_ID);
        if(call AMSend.send(PAN_COORDINATOR_ADDRESS,&pkt,sizeof(connect_msg_t)) == SUCCESS)
        {
            printf("[Node %u] CONNECT sent\n",NODE_ID);
            call TimeoutTimer.startOneShot(CONNECT_TIMEOUT);
        }
    }

    void handle_puback(uint8_t node_id)
    {
        //TODO at the moment, do nothing.
        // a timer-killing routine must be implemented
    }

    //***************** TaskSimpleMessage Interface ********//
    event void TaskSimpleMessage.runTask(uint8_t code_id, uint8_t node_id)
    {
        switch(code_id)
        {
        case CONNECT_CODE:
            handle_connect();
        }
    }
    //***************** Receive Interface *****************//
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
    {
        uint8_t chunk;
        uint8_t code_id;
        uint8_t node_id;
        uint8_t publish_topic;
	uint8_t msg_pubid;
        uint16_t pub_payload;
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
            call TimeoutTimer.stop();
            printf("[Node %u] CONNACK received\n", NODE_ID);
            state=NODE_STATE_SUBSCRIBING;
            call SensorTimer.startPeriodic( SENSOR_PERIOD );
            post subscribeTask();
            break;
        case PUBLISH_CODE:
            //send puback back
            publish_topic = chunk>>PUBLISH_TOPIC_ALIGNMENT;
            msg_pubid =  ((publish_msg_t *)payload)->publish_id;
	    pub_payload = ((publish_msg_t*)payload)->payload;
            printf("[Node %u] !PUBLISH(pid: %u, topic: %u, payload: %u)\n",NODE_ID,msg_pubid,publish_topic,pub_payload);
	    if ( ((qos_mask>>publish_topic)&1)==1)
            {
                call SendPubAckTask.postTask(NODE_ID,publish_topic,msg_pubid);
            }
            break;
        case SUBACK_CODE:
            call TimeoutTimer.stop();
	    state = NODE_STATE_PUBLISHING;
            printf("[Node %u] SUBACK received!\n",NODE_ID);
            break;
        case PUBACK_CODE:
	    msg_pubid = ((uint8_t *)payload)[1];
            printf("[Node %u] PUBACK(pid: %u) Received!\n",NODE_ID, msg_pubid);
            break;
	default: printf("[Node %u] ERROR invalid code_id %u received",NODE_ID,code_id );
        }
        return msg;
    }

    //*************** AMSend Interface ************************//
    event void AMSend.sendDone(message_t* buf,error_t err)
    {
	   if(err!=SUCCESS || (state>=NODE_STATE_PUBLISHING && !(call PacketAcknowledgements.wasAcked(buf))) )
	   {
		if(call AMSend.send(PAN_COORDINATOR_ADDRESS,buf,call Packet.payloadLength(buf)) == SUCCESS)
	        {
           		//printf("[Node %u] *Resent* Packet\n",NODE_ID);
       		}
	   }
    }

    //************************* Read interfaces **********************//
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
            post subscribeTask();
            break;
        }
    }


    task void subscribeTask()
    {
        subscribe_msg_t * mess = call Packet.getPayload(&pkt,sizeof(subscribe_msg_t));
        build_subscribe_msg(mess,NODE_ID,topic_mask,qos_mask);
        if(call AMSend.send(PAN_COORDINATOR_ADDRESS,&pkt,sizeof(subscribe_msg_t)) == SUCCESS)
        {
            call TimeoutTimer.startOneShot(CONNECT_TIMEOUT);
            printf("[Node %u] !SUBSCRIBE(%u,%u)\n",NODE_ID,topic_mask,qos_mask);
        }
    }


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
            printf("[Node %u] !PUBLISH(qos:%u,node_pubid:%u,topic:%u,payload:%u)\n",NODE_ID,qos,node_publish_id,topic,payload);
        }
    }

    event void SendPubAckTask.runTask(uint8_t node_id, uint8_t panc_publish_topic,uint8_t panc_publish_id)
    {
        puback_msg_t * mess = call Packet.getPayload(&pkt,sizeof(puback_msg_t));
        build_puback_msg(mess,NODE_ID,panc_publish_topic,panc_publish_id);
	call PacketAcknowledgements.requestAck(&pkt);
        if(call AMSend.send(PAN_COORDINATOR_ADDRESS,&pkt,sizeof(puback_msg_t)) == SUCCESS)
        {
            printf("[Node %u] !PUBACK(publish_id:%u,topic:%u)\n",NODE_ID,panc_publish_id,panc_publish_topic);
        }
    }

}
