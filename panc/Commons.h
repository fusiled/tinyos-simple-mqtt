#ifndef COMMONS_H
#define COMMONS_H


#define GENERAL_NODE_ID_ALIGNMENT 3

#define PAN_COORDINATOR_ADDRESS 9

enum{
AM_MY_MSG = 6,
};

typedef nx_uint16_t subscribe_msg_t;

typedef nx_uint8_t suback_msg_t;
typedef nx_uint8_t puback_msg_t;
typedef nx_uint8_t connect_msg_t;
typedef nx_uint8_t connack_msg_t;
typedef nx_struct publish_msg_struct
{
	nx_uint8_t header;
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


#define PUBLISH_CODE 3
#define PUBLISH_NODE_ID_ALIGNMENT GENERAL_NODE_ID_ALIGNMENT
#define PUBLISH_TOPIC_ALIGNMENT (PUBLISH_NODE_ID_ALIGNMENT + 3)
#define PUBLISH_QOS_ALIGNMENT ( 0 )
#define PUBLISH_PAYLOAD_ALIGNMENT  (PUBLISH_QOS_ALIGNMENT + 1)
void build_publish_msg(publish_msg_t * msg,uint8_t node_id,bool qos,uint8_t topic,uint16_t payload)
{
	msg->header=PUBLISH_CODE;
	msg->header|=node_id<<PUBLISH_NODE_ID_ALIGNMENT;
	msg->header|=topic<<PUBLISH_TOPIC_ALIGNMENT;
	msg->payload=qos<<PUBLISH_QOS_ALIGNMENT;
	//cut additional bit. We can use only at most 15 bits of payload
	payload=(payload<<1)>>1;
	msg->payload|=payload<<PUBLISH_PAYLOAD_ALIGNMENT;
}


#define SUBSCRIBE_CODE 5
#define SUBSCRIBE_NODE_ID_ALIGNMENT (GENERAL_NODE_ID_ALIGNMENT)
#define SUBSCRIBE_TOPIC_MASK_ALIGNMENT (SUBSCRIBE_NODE_ID_ALIGNMENT + 3 + 2)
#define SUBSCRIBE_QOS_MASK_ALIGNMENT (SUBSCRIBE_TOPIC_MASK_ALIGNMENT + 3 + 1)
void build_subscribe_msg(subscribe_msg_t * msg,uint8_t node_id,uint8_t topic_mask, uint8_t qos_mask)
{
	*msg=SUBSCRIBE_CODE;
	*msg|=node_id<<SUBSCRIBE_NODE_ID_ALIGNMENT;
	*msg|=topic_mask<<SUBSCRIBE_TOPIC_MASK_ALIGNMENT;
	*msg|=qos_mask<<SUBSCRIBE_QOS_MASK_ALIGNMENT;
}


#define CONNECT_CODE 1
#define CONNECT_NODE_ID_ALIGNMENT (GENERAL_NODE_ID_ALIGNMENT)
void build_connect_msg(connect_msg_t * msg,uint8_t node_id)
{
	*msg=CONNECT_CODE;
	*msg|=node_id<<CONNECT_NODE_ID_ALIGNMENT;
}

#define CONNACK_CODE 2
#define CONNACK_NODE_ID_ALIGNMENT (GENERAL_NODE_ID_ALIGNMENT)
void build_connack_msg(connack_msg_t * msg, uint8_t node_id)
{
	*msg=CONNACK_CODE;
	*msg|=node_id<<CONNACK_NODE_ID_ALIGNMENT;
}

#define PUBACK_CODE 4
#define PUBACK_NODE_ID_ALIGNMENT (GENERAL_NODE_ID_ALIGNMENT)
void build_puback_msg(puback_msg_t * msg,uint8_t node_id)
{
	*msg=PUBACK_CODE;
	*msg|=node_id<<PUBACK_NODE_ID_ALIGNMENT;
}

#define SUBACK_CODE 6
#define SUBACK_NODE_ID_ALIGNMENT (GENERAL_NODE_ID_ALIGNMENT)
void build_suback_msg(suback_msg_t * msg,uint8_t node_id)
{
	*msg=SUBACK_CODE;
	*msg|=node_id<<SUBACK_NODE_ID_ALIGNMENT;
}



#endif