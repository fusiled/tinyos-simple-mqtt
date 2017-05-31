module SubscribeTaskC
{
	provides interface SubscribeTask;
}
implementation
{

	async error_t command SubscribeTask.postTask(uint8_t node_id, uint8_t topic_mask,uint8_t qos_mask)
	{
		signal SubscribeTask.runTask(node_id,topic_mask,qos_mask);
		return SUCCESS;
	}

}
