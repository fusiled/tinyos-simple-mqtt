interface SubscribeTask {
  async error_t command postTask(uint8_t node_id, uint8_t topic_mask,uint8_t qos_mask);
  event void runTask(uint8_t node_id,uint8_t topic_mask,uint8_t qos_mask);
}
