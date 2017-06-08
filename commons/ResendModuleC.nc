
#ifndef RESEND_BUFFER_SIZE
#define RESEND_BUFFER_SIZE 160
#endif

#define RESEND_DELTA_TIME 16 

#define RESEND_MODULE_NO_ACK 0
#define RESEND_MODULE_ACK 1

module ResendModuleC
{
    uses
    {
        interface Timer<TMilli> as ResendTimer;
    }

    provides interface ResendModule;
}
implementation
{

    message_t buffer[RESEND_BUFFER_SIZE];
    uint8_t buffer_payload_size[RESEND_BUFFER_SIZE];
    uint8_t buffer_destination[RESEND_BUFFER_SIZE];
    bool buffer_ack_requested[RESEND_BUFFER_SIZE];
    uint8_t head=0;
    uint8_t tail=0;
    bool empty=TRUE;

    command error_t ResendModule.pushMessage(uint8_t destination, message_t msg, uint8_t payload_size,bool ack_requested)
    {
        if(head==tail && !empty)
        {
            return FAIL;
        }
        else
        {
            buffer[tail]=msg;
            buffer_destination[tail]=destination;
	    buffer_payload_size[tail]=payload_size;
	    buffer_ack_requested[tail]=ack_requested;
            tail=(tail+1)%RESEND_BUFFER_SIZE;
            empty=FALSE;
            if(!( call ResendTimer.isRunning() ) )
            {
                call ResendTimer.startOneShot(RESEND_DELTA_TIME);
            }
            return SUCCESS;
        }
    }

    event void ResendTimer.fired()
    {
        uint8_t destination_address;
        uint8_t payload_size;
	bool ack_requested;
        message_t pkt;
	destination_address=buffer_destination[head];
        payload_size=buffer_payload_size[head];
	ack_requested=buffer_ack_requested[head];
        pkt = buffer[head];
	signal ResendModule.sendMessage(destination_address,pkt,payload_size,ack_requested);
	head=(head+1)%RESEND_BUFFER_SIZE;
        if(head==tail)
        {
            empty=TRUE;
        }
        else
        {
            call ResendTimer.startOneShot(RESEND_DELTA_TIME);
        }
    }
}
