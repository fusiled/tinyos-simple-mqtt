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
		call SplitControl.start();
	}


        //*********** SplitControl interface ******************//
	event void SplitControl.startDone(error_t err)
	{
    		if(err == SUCCESS) 
		{
	  		printf("Pan Coordinator Ready\n");
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
		printf("Pan Coordinator is now connected with Node %d", node_id);
		connack_pkt = call Packet.getPayload(&pkt,sizeof(connack_msg_t));
		build_connack_msg(connack_pkt,node_id);
		if( call AMSend.send(node_id,&pkt, sizeof(connack_msg_t)) != SUCCESS)
		{
			//TODO handle error
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
			case CONNECT_CODE: handle_connect(node_id); break;
			case PUBACK_CODE: handle_puback(node_id); break;
			default: printf("Invalid code at Task on panC\n");
		}
	}
	//***************** Receive Interface *****************//
	event message_t * Receive.receive(message_t* msg, void* payload, uint8_t len)
	{
		//get the first 8 bits. They always contains code_id and node_id
		uint8_t chunk=* ((uint8_t*)payload);
		//consider only the important bits
		uint8_t code_id=chunk & 7;
		uint8_t node_id= (chunk & (7<<3))>>3;
		printf("PanC received a message\n");
		switch(code_id)
		{
			case PUBACK_CODE: //use CONNECT_CODE case
			case CONNECT_CODE:
				if(call TaskSimpleMessage.postTask(code_id,node_id)!=SUCCESS)
				{
					//TODO implement timer for task repost
				}
				break;
			case PUBLISH_CODE: break;
			case SUBSCRIBE_CODE: break;
			default: printf("invalid code recevied at PanC\n");
		}
  		return msg;
	}

	//*************** AMSend Interface ************************//
	event void AMSend.sendDone(message_t* buf,error_t err) 
	{
		if(err != SUCCESS )
		{
			printf("Panc Failed msg transmission retrying...");
			//TODO continue failure handling with retransmission
    		}
	}

}