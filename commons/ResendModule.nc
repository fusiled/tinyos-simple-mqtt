interface ResendModule
{
	command error_t pushMessage(uint8_t destination, message_t msg, uint8_t payload_size, bool ack_requested);
	event void sendMessage(uint8_t destination, message_t msg, uint8_t payload_size, bool ack_requested);
}
