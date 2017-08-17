/***************************************************
*
* NodeC wiring. Nothing of special. Just note
* SerialPrintfC to print with printf to stdout
*
***************************************************/



#define NEW_PRINTF_SEMANTICS
#include "printf.h"

configuration NodeAppC
{
}
implementation
{
    //The component
    components NodeC;
    //MainC
    components MainC;
    components ResendModuleC;
    //Network components
    components new AMSenderC(AM_MY_MSG);
    components new AMReceiverC(AM_MY_MSG);
    components ActiveMessageC;

    components TaskSimpleMessageC;
    components PublishTaskC as SendPublishTaskC;
    components PubAckTaskC as SendPubAckTaskC;

    //timers
    components new TimerMilliC() as SensorTimerC;
    components new TimerMilliC() as TimeoutTimerC;

    //printf components
    components SerialPrintfC;
    components SerialStartC;

    //read values
    components new FakeSensorC() as TemperatureSensor;
    components new FakeSensorC() as HumiditySensor;
    components new FakeSensorC() as LuminositySensor;

    components new TimerMilliC() as ResendTimerC;


    /************* WIRINGS *******************/

    NodeC.Boot -> MainC;
    NodeC.Receive -> AMReceiverC;
    NodeC.AMSend -> AMSenderC;
    NodeC.SplitControl -> ActiveMessageC;
    NodeC.PacketAcknowledgements -> ActiveMessageC;
    NodeC.Packet -> AMSenderC;

    NodeC.TaskSimpleMessage -> TaskSimpleMessageC;
    NodeC.SendPublishTask -> SendPublishTaskC;
    NodeC.SendPubAckTask -> SendPubAckTaskC;

    NodeC.TemperatureRead -> TemperatureSensor;
    NodeC.HumidityRead -> HumiditySensor;
    NodeC.LuminosityRead -> LuminositySensor;

    NodeC.SensorTimer -> SensorTimerC;
    NodeC.TimeoutTimer -> TimeoutTimerC;

    NodeC.ResendBuffer -> ResendModuleC;
    ResendModuleC.ResendTimer -> ResendTimerC;


}
