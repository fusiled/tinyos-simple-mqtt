interface PublishTask {
  async error_t command postTask(uint8_t node_id, uint8_t publish_qos,uint8_t node_publish_id,uint8_t publish_topic,uint16_t publish_payload);
  event void runTask(uint8_t node_id, uint8_t publish_qos,uint8_t node_publish_id,uint8_t publish_topic,uint16_t publish_payload);
}
