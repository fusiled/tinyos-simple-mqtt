interface TaskSimpleMessage {
  async error_t command postTask(uint8_t code_id,uint8_t node_id);
  event void runTask(uint8_t code_id, uint8_t node_id);
}
