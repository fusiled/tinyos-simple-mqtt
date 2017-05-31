module PubAckTaskC
{
	provides interface PubAckTask;
}
implementation
{

	async error_t command PubAckTask.postTask(uint8_t node_id, uint8_t publish_topic,uint8_t publish_id)
	{
		signal PubAckTask.runTask(node_id,publish_topic,publish_id);
		return SUCCESS;
	}

}
