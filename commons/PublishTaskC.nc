module PublishTaskC
{
	provides interface PublishTask;
}
implementation
{

	async error_t command PublishTask.postTask(uint8_t node_id, uint8_t publish_qos,uint8_t node_publish_id,uint8_t publish_topic,uint16_t publish_payload)
	{
		signal PublishTask.runTask(node_id,publish_qos,node_publish_id,publish_topic,publish_payload);
		return SUCCESS;
	}

}
