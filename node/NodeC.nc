#include "Commons.h"
#include "printf.h"

#ifndef N_NODES
	#define N_NODES 8
#endif

module NodeC
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
		interface Read<uint16_t> as TemperatureRead;
		interface Read<uint16_t> as HumidityRead;
		interface Read<uint16_t> as LuminosityRead;
 	}

}
implementation
{
	bool connected = FALSE;
	message_t pkt;	
	//***************** Boot interface ********************//
  	event void Boot.booted() {
  		connected = FALSE;
		call SplitControl.start();
	}


        //*********** SplitControl interface ******************//
	event void SplitControl.startDone(error_t err)
	{
    		if(err == SUCCESS) 
		{
	  		printf("[Node %d] READY! Connecting to PanCoordinator\n",TOS_NODE_ID);
			call TaskSimpleMessage.postTask(CONNECT_CODE,TOS_NODE_ID);
 		}
		else
		{
			call SplitControl.start();
		}
	}

	event void SplitControl.stopDone(error_t err){}

	//***************** Message Handlers *****************//
	void handle_connect()
	{
		connect_msg_t * mess=call Packet.getPayload(&pkt,sizeof(connect_msg_t));
		build_connect_msg(mess,TOS_NODE_ID);
		if(call AMSend.send(PAN_COORDINATOR_ADDRESS,&pkt,sizeof(connect_msg_t)) == SUCCESS)
		{
			printf("[Node %d] CONNECT(%d) sent\n",TOS_NODE_ID,TOS_NODE_ID);
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
			case CONNECT_CODE: handle_connect(); 
		}
	}
	//***************** Receive Interface *****************//
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
	{
		//get the first 8 bits. They always contains code_id and node_id
		uint8_t chunk=* ((uint8_t*)payload);
		//consider only the important bits
		uint8_t code_id=chunk & 7;
		uint8_t node_id= (chunk & (7<<3))>>3;
		switch(code_id)
		{
			case PUBACK_CODE: //use CONNECT_CODE case
			case CONNACK_CODE:
				printf("[Node %d] CONNACK received!", TOS_NODE_ID); 
				connected=TRUE; 
				break;
			case PUBLISH_CODE: break;
			case SUBSCRIBE_CODE: break;
		}
  		return msg;
	}

	//*************** AMSend Interface ************************//
	event void AMSend.sendDone(message_t* buf,error_t err) 
	{
		if(err != SUCCESS )
		{
			dbg("radio_send", "Failed msg transmission retrying...");
			//TODO continue failure handling with retransmission
    		}
	}

	//************************* Read interfaces **********************//
	 event void TemperatureRead.readDone(error_t result, uint16_t data)
	{
		
	}

	event void HumidityRead.readDone(error_t result, uint16_t data)
	{
		
	}

	event void LuminosityRead.readDone(error_t result, uint16_t data)
	{
		
	}

}
