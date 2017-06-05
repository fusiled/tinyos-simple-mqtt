#include "Commons.h"

#define NEW_PRINTF_SEMANTICS
#include "printf.h"

configuration PanCApp
{
}
implementation
{
    //THE components
    components PanC;
    //main
    components MainC;
    //network components
    components new AMSenderC(AM_MY_MSG);
    components new AMReceiverC(AM_MY_MSG);
    components ActiveMessageC;
    components ResendModuleC;
    //task components
    components TaskSimpleMessageC;
    components SubscribeTaskC;
    components PublishTaskC;

    //printf components
    components SerialPrintfC;
    components SerialStartC;


    components new TimerMilliC() as ResendTimerC;

    /***************** WIRINGS *************************/
    PanC.Boot -> MainC;
    PanC.Receive -> AMReceiverC;
    PanC.AMSend -> AMSenderC;
    PanC.SplitControl -> ActiveMessageC;
    PanC.PacketAcknowledgements -> ActiveMessageC;
    PanC.TaskSimpleMessage -> TaskSimpleMessageC;
    PanC.SubscribeTask -> SubscribeTaskC;
    PanC.PublishTask -> PublishTaskC;

    PanC.ResendBuffer -> ResendModuleC;
    ResendModuleC.ResendTimer -> ResendTimerC;

    PanC.AMPacket -> AMSenderC;
    PanC.Packet -> AMSenderC;
}
