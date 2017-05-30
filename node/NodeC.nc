#include "Commons.h"
#include "printf.h"

#ifndef N_NODES
	#define N_NODES 8
#endif


#define SENSOR_PERIOD 1024
#define CONNECT_TIMEOUT 2048
#define NODE_ID (TOS_NODE_ID - 1 )
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
		interface Timer<TMilli> as SensorTimer;
		interface Timer<TMilli> as TimeoutTimer;
 	}

}
implementation
{
	bool connected = FALSE;
	message_t pkt;	
	uint8_t sensor_selector = 0;

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
	  		printf("[Node %d] READY! Connecting to PanCoordinator\n",NODE_ID);
			call TaskSimpleMessage.postTask(CONNECT_CODE,NODE_ID);
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
		build_connect_msg(mess,NODE_ID);
		if(call AMSend.send(PAN_COORDINATOR_ADDRESS,&pkt,sizeof(connect_msg_t)) == SUCCESS)
		{
			printf("[Node %d] CONNECT(%d) sent\n",NODE_ID,NODE_ID);
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
		printf("[Node %d] received message. code_id: %d, node_id: %d\n", NODE_ID,code_id,node_id);
		switch(code_id)
		{
			case CONNACK_CODE: printf("[Node %d] CONNACK received!\n", NODE_ID);
				connected=TRUE;
				call SensorTimer.startPeriodic(SENSOR_PERIOD); 
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
			printf("[Node %d] Failed msg transmission retrying...\n", NODE_ID);
			//TODO continue failure handling with retransmission
    		}
	}

	//************************* Read interfaces **********************//
	 event void TemperatureRead.readDone(error_t result, uint16_t data)
	{
		if(result==SUCCESS)
                {
                        //printf("[Node %d] TEM: %d\n", NODE_ID,data);
                }
                else
                {
                        printf("[Node %d] TEM: FAIL\n",NODE_ID);
                }

	}

	event void HumidityRead.readDone(error_t result, uint16_t data)
	{
		if(result==SUCCESS)
                {
                        //printf("[Node %d] HUM: %d\n", NODE_ID,data);
                }
                else
                {
                        printf("[Node %d] HUM: FAIL\n",NODE_ID);
                }

	}

	event void LuminosityRead.readDone(error_t result, uint16_t data)
	{
		if(result==SUCCESS)
		{
			//printf("[Node %d] LUM: %d\n", NODE_ID,data);
		}
		else
		{
			printf("[Node %d] LUM: FAIL\n",NODE_ID);
		}
	}

	event void SensorTimer.fired() 
	{
		switch(sensor_selector%3)
		{
			case 0: call TemperatureRead.read(); break;
			case 1: call HumidityRead.read(); break;
			case 2: call LuminosityRead.read(); break;
		}
		sensor_selector++;
	}

	event void TimeoutTimer.fired()
	{
		if(connected!=TRUE)
		{
			printf("[Node %d] CONNACK not received. Retrying...\n",NODE_ID);
			call TaskSimpleMessage.postTask(CONNECT_CODE,NODE_ID);
		}
	}
}
