#
# Send message:
#
import pulsar

client = pulsar.Client('pulsar://ap-c1-n1:6650')

producer = client.create_producer('test-topic-1')

for i in range(10):
    producer.send(('Hello-%d' % i).encode('utf-8'))

client.close()

#::END:: 
