# Simple MQTT protocol with TinyOS
This is the project of the Internet of Things course at Politecnico di Milano, Accademic Year 2016/2017. The goal is to create a simple MQTT protocol based on the specification described in the following section.

## Project Description
The request is to design and implement a lightweight publish-subscribe applicatio protocol similar to MQTT and test it with simulations on a star-shaped network topology composed by 8 client nodes connected to a PAN coordinator.  The PAN coordinator acts as a MQTT broker.
The following features need to be implemented:

1. Connection: upon activation, each node sends a CONNECT message to the PAN coordinator. The PAN coordinator replies with a CONNACK message.
2. Subscribe: each node can subscribe to one among these three topics: TEMPERATURE, HUMIDITY, LUMINOSITY. In order to subscribe, a node sends a SUBSCRIBE message to the PAN, containing its ID and the topics it wants to subscribe to. For each topic a value of Quality of Service is set, QoS 0 or Qos 1, whose function is the same as the actual MQTT QoS levels (i.e. QoS 0 = at most once, QoS 1 = at least once). The subscribe message is acknowledged by the PAN with a SUBACK message.
3. Publish: each node can publish data on at most one of the three afore mentioned topics. Publication is performed through a PUBLISH message with the following fields: topic name, payload and QoS levels (i.e. QoS 0 = at most once, QoS 1 = at least once). When a node publish a message on a topic, this is received by the PAN and forwarded to all nodes that have subscribed to a particular topic.
4.  QoS management: like in MQTT each message is subject to two levels of QoS. For PUBLISH messages, the QoS controls the transmission from a node to the PAN coordinator. If QoS is set to 0, the node transmit the message just once. If QoS is set to 1, the node keeps retransmitting the message until the PAN coordinator acknowledges it with a PUBACK message. The same holds for subscriptions: the PAN coordinator forwards the message received on a topic to all nodes subscribed to that topic, using the QoS logic independently for each node (according to what a node has specified in the SUBSCRIBE message).

##Packet Specification
There are 6 different kind of packet. Packet construction is performed by the functions contained in `commons/Commons.h`
