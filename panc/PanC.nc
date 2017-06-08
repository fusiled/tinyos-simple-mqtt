
/**************************************************************
*
* PanC Pan Coordinator of the network. See the specification
* to knwo what the pan coordinator must do.
*
* The idea is to decouple the logic with taskss. The idea of tasks
* with params is taken by the following resource:
* https://github.com/tinyos/tinyos-main/blob/master/doc/txt/tep106.txt
* Debug is performed through printf.
*
* PanC exploits a ResendBuffer offered by the ResendModule interface.
* Check ResendModuleC.nc
*
* active_node, qos and topic represent the state of the nodes. The position
* i represents the node i. qos and topic are bit masks. Bit:
* 0 is associated to TEMPERATURE
* 1 is associated to HUMIDITY
* 2 is associated to LUMINOSITY
*
* publish_id is a variable that identifies a publish. It could be used for advanced
* mechanisms.
*
*************************************************************/


//Include for message structs
#include "Commons.h"
//include for printf
#include "printf.h"


#ifndef N_NODES
#define N_NODES 8
#endif


module PanC {
    uses
    {
        //Boot interface for init of the module
        interface Boot;
        //Task interfaces. Seee the related NameInterfaceC.nc module
        //for further details
        interface TaskSimpleMessage;
        interface PublishTask;
        interface SubscribeTask;
        //Network interfaces
        interface AMPacket;
        interface Packet;
        interface AMSend;
        interface SplitControl;
        interface Receive;
        interface PacketAcknowledgements;
        //Interface for the resendBuffer
        interface ResendModule as ResendBuffer;
    }
}
implementation {

    //active_nodes represents if the i-th node has been connected to PanC
    bool active_node[N_NODES];
    //Qos mask for the node at position i
    uint8_t qos[N_NODES];
    //topic mask for the node at position i
    uint8_t topic[N_NODES];
    uint8_t publish_id = 0;
    
    //variable used to send a message. Be careful with the race conditions.
    message_t resend_pkt;
    message_t publish_pkt;
    message_t puback_pkt;
    message_t connack_pkt;
    message_t suback_pkt;
    //***************** Boot interface ********************//
    event void Boot.booted()
    {
        call SplitControl.start();
    }


    //*********** SplitControl interface ******************//
    event void SplitControl.startDone(error_t err)
    {
        if(err == SUCCESS)
        {
            printf("[PanC] Ready\n");
	    printf("SIZE: connect: %u, publish: %u, puback: %u\n",sizeof(connect_msg_t),sizeof(publish_msg_t),sizeof(puback_msg_t));
        }
        else
        {
            call SplitControl.start();
        }
    }

    event void SplitControl.stopDone(error_t err) {}

    //***************** Message Handlers *****************//

    //This function is called when a CONNECT is received. It just set the related field
    //of the array active_node to true and send a connact back. An ack is not strictly needed
    //because if the node won't receive the ack it will try to reconnect.
    void handle_connect(uint8_t node_id)
    {
        connack_msg_t * connack_msg;
        active_node[node_id]=TRUE;
        connack_msg = call Packet.getPayload(&connack_pkt,sizeof(connack_msg_t));
        build_connack_msg(connack_msg,node_id);
        if( call AMSend.send( (node_id+1) ,&connack_pkt, sizeof(connack_msg_t)) == SUCCESS)
        {
            printf("[PanC] Sent CONNACK(%u)\n",node_id);
        }
    }


    //Just printf that the PanC has received a PUBACK
    void handle_puback(uint8_t node_id,uint8_t node_publish_id)
    {
        printf("[PanC] !PUBACK(nid:%u,pubid:%u)\n",node_id, node_publish_id);
    }

    //Function that manages the action of sending a SUBACK. Just like CONNACK,
    //if the node wont' receive the SUBACK then it will try to resend a SUBSCRIBE
    void handle_suback(uint8_t node_id)
    {
        suback_msg_t * suback_msg;
        suback_pkt = call Packet.getPayload(&suback_msg,sizeof(suback_msg_t));
        build_suback_msg(suback_msg,node_id);
        if( call AMSend.send( (node_id+1) ,&suback_pkt, sizeof(suback_msg_t)) == SUCCESS)
        {
            printf("[PanC] Sent SUBACK(%u)\n",node_id);
        }
    }

    //***************** TaskSimpleMessage Interface ********//
    event void TaskSimpleMessage.runTask(uint8_t code_id, uint8_t node_id)
    {
        switch(code_id)
        {
        case CONNECT_CODE:
            handle_connect(node_id);
            break;
        case SUBACK_CODE:
            handle_suback(node_id);
            break;
        default:
            printf("[PanC] ERROR Invalid code_id %u TaskSimpleMessage.runTask\n",code_id);
        }
    }
    //***************** Receive Interface *****************//

    //Get the message and act basing ont its code.
    event message_t * Receive.receive(message_t* msg, void* payload, uint8_t len)
    {
        //Declare variables. I know... they're a lot
        uint8_t header;
        uint8_t code_id;
        uint8_t node_id;
        uint8_t topic_mask;
        uint8_t qos_mask;
        uint8_t publish_qos;
        uint16_t publish_payload;
        uint8_t publish_topic;
        uint8_t node_publish_id;
        subscribe_msg_t * sub_msg;
        if(len==sizeof(suback_msg_t) || len==sizeof(connect_msg_t)|| len==sizeof(connack_msg_t))
        {
            header = *((uint8_t *)payload);
        }
        else if(len==sizeof(subscribe_msg_t) || len==sizeof(puback_msg_t))
        {
            header = ((uint8_t *)payload)[1];
        }
        else if(len==sizeof(publish_msg_t))
        {
            publish_msg_t * pub_msg = (publish_msg_t *) payload;
            header = pub_msg->header;
        }
        else
        {
            printf("[PanC] ERROR Reception of a wrong size ):\n");
            return msg;
        }
        code_id=header & CODE_ID_MASK;
        node_id= (header >> GENERAL_NODE_ID_ALIGNMENT) & NODE_ID_MASK;
        //printf("[PanC] new msg. code_id: %u, node_id: %u\n", code_id,node_id);
        switch(code_id)
        {
        case PUBACK_CODE:
            node_publish_id=((puback_msg_t)payload)>>PUBACK_ID_ALIGNMENT;
            handle_puback(node_id,node_publish_id);
            break;
        case CONNECT_CODE:
            call TaskSimpleMessage.postTask(code_id,node_id);
            break;
        case PUBLISH_CODE:
            publish_qos =( ((publish_msg_t *)payload)->payload ) & 1;
            publish_topic = header >> PUBLISH_TOPIC_ALIGNMENT;
            publish_payload = ( ((publish_msg_t *)payload)->payload )>>1;
            node_publish_id = ((publish_msg_t *)payload)->publish_id;
            call PublishTask.postTask(node_id,publish_qos,node_publish_id,publish_topic,publish_payload);
            break;
        case SUBSCRIBE_CODE:
            sub_msg = (subscribe_msg_t *)payload;
            topic_mask = (*sub_msg >> SUBSCRIBE_TOPIC_MASK_ALIGNMENT) & SUBSCRIBE_TOPIC_MASK;
            qos_mask = (*sub_msg >> SUBSCRIBE_QOS_MASK_ALIGNMENT) & SUBSCRIBE_QOS_MASK;
            call SubscribeTask.postTask(node_id,topic_mask,qos_mask);
            break;
        default:
            printf("[PanC] ERROR Invalid code:%u. node_id %u at Receive.receive. size: %u, payload: %x\n", code_id,node_id,len,*((uint8_t*)payload) );
        }
        return msg;
    }

    //*************** AMSend Interface ************************//
    event void AMSend.sendDone(message_t* buf,error_t err)
    {
        if(err != SUCCESS )
        {
            uint8_t buf_size;
            uint8_t node_id;
            uint8_t ack_requested;
            printf("[Panc] Failed msg transmission!");
            buf_size=call Packet.payloadLength(buf);
            if(buf_size==sizeof(suback_msg_t) || buf_size==sizeof(connect_msg_t)|| buf_size==sizeof(connack_msg_t))
            {
                node_id =  ( (*((uint8_t *)buf))>>GENERAL_NODE_ID_ALIGNMENT) & NODE_ID_MASK;
                ack_requested=0;
            }
            else if(buf_size==sizeof(subscribe_msg_t) || buf_size==sizeof(puback_msg_t))
            {
                uint8_t code_id = (((uint8_t*)buf)[1]) & CODE_ID_MASK;
                node_id = ( (((uint8_t *)buf)[1])>>GENERAL_NODE_ID_ALIGNMENT) & NODE_ID_MASK;
                if(code_id==PUBACK_CODE)
                {
                    ack_requested=1;
                }
                else
                {
                    ack_requested=0;
                }
            }
            else if(buf_size==sizeof(publish_msg_t))
            {
                uint8_t publish_topic;
                node_id = ( (  ((publish_msg_t *)buf)->header)>>GENERAL_NODE_ID_ALIGNMENT) & NODE_ID_MASK;
                publish_topic =  ( ( ((publish_msg_t *)buf)->header)>>PUBLISH_TOPIC_ALIGNMENT) & PUBLISH_TOPIC_MASK;
                ack_requested = (qos[node_id]>>publish_topic) & 1;
            }
            else
            {
                return;
            }

            //get node id
            if(call AMSend.send(node_id+1,buf,buf_size) == SUCCESS)
            {
                //printf("[PanC] *Resent* Packet\n");
            }
            else
            {
                printf("[PanC] ERROR Failure in Packet resend\n");
                if( (call ResendBuffer.pushMessage(node_id+1,*buf,buf_size,ack_requested))!=SUCCESS)
                {
                    printf("[PanC] ERROR ResendBuffer is full. Discard Packet\n");
                }
            }
        }
    }

    event void SubscribeTask.runTask(uint8_t node_id, uint8_t topic_mask, uint8_t qos_mask)
    {
        if(active_node[node_id]==TRUE)
        {
            topic[node_id]=topic_mask;
            qos[node_id]=qos_mask;
            printf("[PanC] set node: %u, topic: %u, qos: %u\n", node_id,topic[node_id],qos[node_id]);
            call TaskSimpleMessage.postTask(SUBACK_CODE,node_id);
        }
    }


    event void PublishTask.runTask(uint8_t node_id, uint8_t publish_qos,uint8_t node_publish_id, uint8_t publish_topic,uint16_t publish_payload)
    {
        uint16_t iterator;
        //send PUBACK to node
        if(publish_qos==1)
        {
            puback_msg_t * puback_msg = call Packet.getPayload(&puback_pkt,sizeof(puback_msg_t));
            build_puback_msg(puback_msg,node_id,publish_topic,node_publish_id);
            call PacketAcknowledgements.requestAck(&puback_pkt);
            if( call AMSend.send( (node_id+1) ,&puback_pkt, sizeof(puback_msg_t)) == SUCCESS)
            {
                printf("[PanC] Sent PUBACK(nid:%u, node_pub_id: %u)\n",node_id, node_publish_id);
            }
            else
            {
                printf("[Panc] FAILED PUBACK SENT nid:%u, node_pub_id: %u).Pushing in ResendBuffer\n",node_id, node_publish_id);
                if( (call ResendBuffer.pushMessage(node_id+1,puback_pkt,sizeof(puback_msg_t),1))!=SUCCESS)
                {
                    printf("[PanC] ERROR ResendBuffer is full. Discard Packet\n");
                }

            }
        }
	printf("[PanC] publish (%u,%u) had panc_pub_id of %u\n",node_id,node_publish_id,publish_id);
        for(iterator=0; iterator<N_NODES; iterator++)
        {
            uint8_t iter_topic = topic[iterator];
            if(iterator!=node_id && active_node[iterator]==TRUE && ( (iter_topic >> publish_topic) & 1 )==1)
            {
                //send publish to that node
                uint8_t sending_qos;
                publish_msg_t * mess = call Packet.getPayload(&publish_pkt,sizeof(publish_msg_t));
                sending_qos = (qos[iterator]>>publish_topic) & 1;
                build_publish_msg(mess,node_id,sending_qos,publish_id,publish_topic,publish_payload);
                if(sending_qos>0)
                {
                    call PacketAcknowledgements.requestAck(&publish_pkt);
                }
                if(call AMSend.send( (iterator+1),&publish_pkt,sizeof(publish_msg_t)) == SUCCESS)
                {
                    printf("[PanC] SENT PUBLISH %u->%u. pub_id: %u, qos: %u, topic: %u, payload: %u\n",node_id,iterator,
                           publish_id, sending_qos,publish_topic,publish_payload);
                }
                else
                {
                    printf("[PanC] FAILED PUBLISH %u->%u. pub_id: %u, qos: %u, topic: %u, payload: %u\n",node_id,iterator,
                           publish_id, sending_qos,publish_topic,publish_payload);
                    if( (call ResendBuffer.pushMessage(iterator+1,publish_pkt,sizeof(publish_msg_t),sending_qos))!=SUCCESS)
                    {
                        printf("[PanC] ERROR ResendBuffer is full. Discard Packet\n");
                    }
                }
            }
        }
        publish_id++;
    }


    event void ResendBuffer.sendMessage(uint8_t destination, message_t msg, uint8_t payload_size, bool ack_requested)
    {
        resend_pkt=msg;
        if(ack_requested)
        {
            call PacketAcknowledgements.requestAck(&resend_pkt);
        }
        if(call AMSend.send( destination,&resend_pkt,payload_size) == SUCCESS)
        {
            //printf("[PanC] Successfully resent message\n");
        }
        else
        {
            //printf("[PanC] Error in resent message. reinserting back into the queue\n");
            if( (call ResendBuffer.pushMessage(destination,msg,payload_size,ack_requested))!=SUCCESS)
            {
                printf("[PanC] ERROR ResendBuffer is full. Discard Packet\n");
            }
        }
    }

}
