#include "Commons.h"



#ifndef N_NODES
	#define N_NODES 8
#endif

#include "printf.h"
module PanC
{
	uses 
	{
		interface TaskSimpleMessage;
		interface PublishTask;
		interface SubscribeTask;
		interface Boot;
	    	interface AMPacket;
		interface Packet;
    		interface AMSend;
	    	interface SplitControl;
		interface Receive;		
 	}
}
implementation
{
	bool active_node[N_NODES];
	uint8_t qos[N_NODES];
	uint8_t topic[N_NODES];
	message_t pkt;	
	connack_msg_t * connack_pkt;

	//***************** Boot interface ********************//
  	event void Boot.booted()
	{
		am_addr_t addr = call AMPacket.address();
		printf("[PanC] address: %d\n", addr);
		call SplitControl.start();
	}


        //*********** SplitControl interface ******************//
	event void SplitControl.startDone(error_t err)
	{
    		if(err == SUCCESS) 
		{
	  		printf("[PanC] Ready!\n");
 		}
		else
		{
			call SplitControl.start();
		}
	}

	event void SplitControl.stopDone(error_t err){}

	//***************** Message Handlers *****************//
	void handle_connect(uint8_t node_id)
	{
		active_node[node_id]=TRUE;
		//printf("[PanC] active_node[%d]=%d\n", node_id, active_node[node_id-1]);
		connack_pkt = call Packet.getPayload(&pkt,sizeof(connack_msg_t));
		build_connack_msg(connack_pkt,node_id);
		if( call AMSend.send( (node_id+1) ,&pkt, sizeof(connack_msg_t)) == SUCCESS)
		{
			printf("[PanC] Sent CONNACK(%d)\n",node_id);
		} 
	}

	void handle_puback(uint8_t node_id)
	{
		//TODO at the moment, do nothing.
		// a timer-killing routine must be implemented
	}


	void handle_suback(uint8_t node_id)
	{
		suback_msg_t * suback_pkt;
                suback_pkt = call Packet.getPayload(&pkt,sizeof(suback_msg_t));
                build_suback_msg(suback_pkt,node_id);
                if( call AMSend.send( (node_id+1) ,&pkt, sizeof(suback_msg_t)) == SUCCESS)
                {
                        printf("[PanC] Sent SUBACK(%d)\n",node_id);
                }

	}

	//***************** TaskSimpleMessage Interface ********//
	event void TaskSimpleMessage.runTask(uint8_t code_id, uint8_t node_id)
	{
		switch(code_id)
		{
			case CONNECT_CODE: handle_connect(node_id); break;
			case PUBACK_CODE: handle_puback(node_id); break;
			case SUBACK_CODE: handle_suback(node_id); break;
			default: printf("[PanC] Invalid code_id %d TaskSimpleMessage.runTask\n",code_id);
		}
	}
	//***************** Receive Interface *****************//
	event message_t * Receive.receive(message_t* msg, void* payload, uint8_t len)
	{
		uint8_t chunk;
		uint8_t code_id;
		uint8_t node_id;
		subscribe_msg_t * sub_msg;
                uint8_t topic_mask;
                uint8_t qos_mask;
		uint8_t publish_qos;
		uint16_t publish_payload;
		uint8_t publish_topic;
		if(len==sizeof(uint8_t))
		{
			chunk = *((uint8_t *)payload);
		}
		else if(len==sizeof(subscribe_msg_t))
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
			printf("[PanC] arrived a packet of wrong size!\n");
			return msg;
		}
		code_id=chunk & 7;
		node_id= (chunk >> 3) & 7;
		printf("[PanC] new msg. code_id: %d, node_id: %d\n", code_id,node_id);
		switch(code_id)
		{
			case PUBACK_CODE: //use CONNECT_CODE case
			case CONNECT_CODE:
				if(call TaskSimpleMessage.postTask(code_id,node_id)!=SUCCESS)
				{
					//TODO implement timer for task repost
				}
				break;
			case PUBLISH_CODE:
				publish_qos =( ((publish_msg_t *)payload)->payload ) & 1;
				publish_topic = chunk >> PUBLISH_TOPIC_ALIGNMENT;
				publish_payload = ( ((publish_msg_t *)payload)->payload )>>1; 
				call PublishTask.postTask(node_id,publish_qos,publish_topic,publish_payload);
				 break;
			case SUBSCRIBE_CODE: sub_msg = (subscribe_msg_t *)payload;
				topic_mask = (*sub_msg >> SUBSCRIBE_TOPIC_MASK_ALIGNMENT) & 7;
                                qos_mask = (*sub_msg >> SUBSCRIBE_QOS_MASK_ALIGNMENT) & 7;
                                call SubscribeTask.postTask(node_id,topic_mask,qos_mask); 
				break;
			case SUBACK_CODE: break;
			default: printf("[PanC] Invalid code %d at Receive.receive\n", code_id);
		}
  		return msg;
	}

	//*************** AMSend Interface ************************//
	event void AMSend.sendDone(message_t* buf,error_t err) 
	{
		if(err != SUCCESS )
		{
			printf("[Panc] Failed msg transmission!");
			//TODO continue failure handling with retransmission
    		}
	}

	event void SubscribeTask.runTask(uint8_t node_id, uint8_t topic_mask, uint8_t qos_mask)
        {
		if(active_node[node_id]==TRUE)
		{
			topic[node_id]=topic_mask;
			qos[node_id]=qos_mask;
			printf("[PanC] set node: %d, topic: %d, qos: %d\n", node_id,topic[node_id],qos[node_id]);
			call TaskSimpleMessage.postTask(SUBACK_CODE,node_id);
		}		
        }


	event void PublishTask.runTask(uint8_t node_id, uint8_t publish_qos,uint8_t publish_topic,uint16_t publish_payload)
	{
		printf("[PanC] PUBLISH from node %d. qos: %d, topic: %d, payload: %d\n", node_id,publish_qos,publish_topic,publish_payload);
	}

}
