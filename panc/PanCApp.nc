#include "Commons.h"

#define NEW_PRINTF_SEMANTICS
#include "printf.h"

configuration PanCApp
{
}
implementation
{
	components MainC;
	components PanC;
	components new AMSenderC(AM_MY_MSG);
	components new AMReceiverC(AM_MY_MSG);
	components ActiveMessageC;
	components TaskSimpleMessageC;	

	//printf components
        components SerialPrintfC;
        components SerialStartC;

	PanC.Boot -> MainC;
	PanC.Receive -> AMReceiverC;
	PanC.AMSend -> AMSenderC;
	PanC.SplitControl -> ActiveMessageC;
	PanC.TaskSimpleMessage -> TaskSimpleMessageC;
	
	PanC.AMPacket -> AMSenderC;
  	PanC.Packet -> AMSenderC;
}
