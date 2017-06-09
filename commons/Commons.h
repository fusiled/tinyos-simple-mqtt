/************************************************************
*
* Header for message structs and creations.
* every type of message have a related struct. see all the typedefs
* declation.
*
* There's a function foreach message that builds it.
* The defines are very useful to get fields of the structs. The
* fields are packed with bit-field operations to reduce the size
* of the packets.
*
************************************************************/



#ifndef COMMONS_H
#define COMMONS_H

#define GENERAL_NODE_ID_ALIGNMENT 3

#define PAN_COORDINATOR_ADDRESS 9

#define NODE_ID_MASK 7
#define CODE_ID_MASK 7
#define PUBLISH_TOPIC_MASK 3
#define PUBLISH_QOS_MASK 1
#define SUBSCRIBE_TOPIC_MASK 7
#define SUBSCRIBE_QOS_MASK 7


enum{
AM_MY_MSG = 6,
};


typedef nx_uint8_t suback_msg_t;
typedef nx_uint8_t connect_msg_t;
typedef nx_uint8_t connack_msg_t;

typedef nx_uint16_t subscribe_msg_t;
typedef nx_uint16_t puback_msg_t;

typedef nx_struct publish_msg_struct
{
	nx_uint8_t header;
	nx_uint8_t publish_id;
	nx_uint16_t payload;
} publish_msg_t;


/*
 * 1 CONNECT
 * 2 CONNACK
 * 3 PUBLISH
 * 4 PUBACK
 * 5 SUBSCRIBE
 * 6 SUBACK
*/

#define CONNECT_CODE 1
//THe node that tries to connect
#define CONNECT_NODE_ID_ALIGNMENT (GENERAL_NODE_ID_ALIGNMENT)
void build_connect_msg(connect_msg_t * msg,uint8_t node_id)
{
	*msg=CONNECT_CODE & CODE_ID_MASK;
	*msg|=(node_id & NODE_ID_MASK)<<CONNECT_NODE_ID_ALIGNMENT;
}

#define CONNACK_CODE 2
//The node that must receive the connack
#define CONNACK_NODE_ID_ALIGNMENT (GENERAL_NODE_ID_ALIGNMENT)
void build_connack_msg(connack_msg_t * msg, uint8_t node_id)
{
	*msg=CONNACK_CODE & CODE_ID_MASK;
	*msg|=(node_id & NODE_ID_MASK)<<CONNACK_NODE_ID_ALIGNMENT;
}

#define PUBLISH_CODE 3
// node_id is the one of the node that published the event
#define PUBLISH_NODE_ID_ALIGNMENT GENERAL_NODE_ID_ALIGNMENT
//The topic of the publish
#define PUBLISH_TOPIC_ALIGNMENT (PUBLISH_NODE_ID_ALIGNMENT + 3)
//id of the publish. It is associated to the node that sends it
#define PUBLISH_ID_ALIGNMENT (0)
//qos of the publish message. If it comes from a node then it is set
//by qos_mask. If it comes from the panc then it is set with qos array
#define PUBLISH_QOS_ALIGNMENT ( 0 )
//the value of the publish
#define PUBLISH_PAYLOAD_ALIGNMENT  (PUBLISH_QOS_ALIGNMENT + 1)
void build_publish_msg(publish_msg_t * msg,uint8_t node_id,bool qos,uint8_t publish_id ,uint8_t topic,uint16_t payload)
{
	msg->header=PUBLISH_CODE & CODE_ID_MASK;
	msg->header|=(node_id & NODE_ID_MASK)<<PUBLISH_NODE_ID_ALIGNMENT;
	msg->header|=(topic & PUBLISH_TOPIC_MASK)<<PUBLISH_TOPIC_ALIGNMENT;
	msg->publish_id=publish_id<<PUBLISH_ID_ALIGNMENT;
	msg->payload=(qos & PUBLISH_QOS_MASK)<<PUBLISH_QOS_ALIGNMENT;
	//cut additional bit. We can use only at most 15 bits of payload
	payload=(payload<<1)>>1;
	msg->payload|=payload<<PUBLISH_PAYLOAD_ALIGNMENT;
}

#define PUBACK_CODE 4
//if it comes from a node then it is the id of the node who replied
//if it comes from panc then it is the id of the node who published
#define PUBACK_NODE_ID_ALIGNMENT (GENERAL_NODE_ID_ALIGNMENT)
//the topic of the publish associated to this PUBACK
#define PUBACK_TOPIC_ALIGNMENT (PUBACK_NODE_ID_ALIGNMENT + 3)
//the id of the publish associated to this PUBACK
#define PUBACK_ID_ALIGNMENT (PUBACK_TOPIC_ALIGNMENT + 2)
void build_puback_msg(puback_msg_t * msg,uint8_t node_id,uint8_t topic, uint8_t publish_id)
{
	*msg=PUBACK_CODE & NODE_ID_MASK;
	*msg|=(node_id & NODE_ID_MASK)<<PUBACK_NODE_ID_ALIGNMENT;
	*msg|=(topic & PUBLISH_TOPIC_MASK)<<PUBACK_TOPIC_ALIGNMENT;
	*msg|=publish_id<<PUBACK_ID_ALIGNMENT;
}

#define SUBSCRIBE_CODE 5
//id of the node who wants to subscribe
#define SUBSCRIBE_NODE_ID_ALIGNMENT (GENERAL_NODE_ID_ALIGNMENT)
//topic mask of the subscription
#define SUBSCRIBE_TOPIC_MASK_ALIGNMENT (SUBSCRIBE_NODE_ID_ALIGNMENT + 3 + 2)
//qos mask of the subscription
#define SUBSCRIBE_QOS_MASK_ALIGNMENT (SUBSCRIBE_TOPIC_MASK_ALIGNMENT + 3 + 1)
void build_subscribe_msg(subscribe_msg_t * msg,uint8_t node_id,uint8_t topic_mask, uint8_t qos_mask)
{
	*msg=(SUBSCRIBE_CODE & 7);
	*msg|=(node_id & NODE_ID_MASK)<<SUBSCRIBE_NODE_ID_ALIGNMENT;
	*msg|=(topic_mask & SUBSCRIBE_TOPIC_MASK)<<SUBSCRIBE_TOPIC_MASK_ALIGNMENT;
	*msg|=(qos_mask & SUBSCRIBE_QOS_MASK)<<SUBSCRIBE_QOS_MASK_ALIGNMENT;
}


#define SUBACK_CODE 6
//node who must receive the suback
#define SUBACK_NODE_ID_ALIGNMENT (GENERAL_NODE_ID_ALIGNMENT)
void build_suback_msg(suback_msg_t * msg,uint8_t node_id)
{
	*msg=SUBACK_CODE & CODE_ID_MASK;
	*msg|=(node_id & NODE_ID_MASK)<<SUBACK_NODE_ID_ALIGNMENT;
}

#endif
