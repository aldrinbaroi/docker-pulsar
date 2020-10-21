#
# Send replicated message
#
# Message must be sent to a topic which is in the replicated namesapce
#

import pulsar

client = pulsar.Client('pulsar://ap-c1-n1:6650')

producer = client.create_producer('non-persistent://test-tenant/test-namespace/test-topic-1')

for i in range(10):
    producer.send(('Hello-%d' % i).encode('utf-8'))

client.close()

#::END:: 
