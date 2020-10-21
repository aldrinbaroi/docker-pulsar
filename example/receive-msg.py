#
# Receive message
#
# To terminate use CTRL+C or send SIGINT signal to the running process
#

import pulsar 
import signal
import sys

def signal_handler(sig, frame):
    print('You pressed Ctrl+C!')
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler) 

client = pulsar.Client('pulsar://ap-c1-n1:6650')

consumer = client.subscribe('test-topic-1', 'test-subscription-1')

while True:
    msg = consumer.receive()
    try:
        print("Received message '{}' id='{}'".format(msg.data(), msg.message_id()))
        # Acknowledge successful processing of the message
        consumer.acknowledge(msg)
    except:
        # Message failed to be processed
        consumer.negative_acknowledge(msg)

client.close()

#::END::

