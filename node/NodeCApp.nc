#define NEW_PRINTF_SEMANTICS
#include "printf.h"


configuration NodeCApp
{
}
implementation
{
	components MainC;
	components NodeC;
	components new AMSenderC(AM_MY_MSG);
        components new AMReceiverC(AM_MY_MSG);
        components ActiveMessageC;

	components TaskSimpleMessageC;
	components PublishTaskC;

	components new TimerMilliC() as SensorTimerC;
	components new TimerMilliC() as TimeoutTimerC;
	//printf components
	components SerialPrintfC;
	components SerialStartC;

	
	components new FakeSensorC() as TemperatureSensor;
	components new FakeSensorC() as HumiditySensor;
	components new FakeSensorC() as LuminositySensor;

        NodeC.Boot -> MainC;
        NodeC.Receive -> AMReceiverC;
        NodeC.AMSend -> AMSenderC;
        NodeC.SplitControl -> ActiveMessageC;

        NodeC.AMPacket -> AMSenderC;
        NodeC.Packet -> AMSenderC;

	NodeC.TaskSimpleMessage -> TaskSimpleMessageC;
	NodeC.PublishTask -> PublishTaskC;	


	NodeC.TemperatureRead -> TemperatureSensor;
	NodeC.HumidityRead -> HumiditySensor;
	NodeC.LuminosityRead -> LuminositySensor;
	NodeC.SensorTimer -> SensorTimerC;
	NodeC.TimeoutTimer -> TimeoutTimerC;
}
