#include "Commons.h"


module TaskSimpleMessageC
{
	provides interface TaskSimpleMessage;
}
implementation
{

	async error_t command TaskSimpleMessage.postTask(uint8_t code_id,uint8_t node_id)
	{
		signal TaskSimpleMessage.runTask(code_id,node_id);
		return SUCCESS;
	}

}
