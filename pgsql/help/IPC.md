[Publisher DB]                      [Subscriber DB]
     |                                    |
     | 1. Replication worker starts       |
     |---------------------------------->|
     |                                    |
     | 2. Worker reads WAL changes       |
     |<----------------------------------|
     |                                    |
     | 3. Send WAL changes to subscriber |
     |---------------------------------->|
     |                                    |
     | 4. Wait for acknowledgement       | <--- LogicalSyncStateChange wait
     |                                    |
     | 5. Receive feedback from subscriber
     |<----------------------------------|
     |                                    |
     | 6. Update replication slot LSN    |
     |                                    |
     | 7. Repeat steps 2–6 continuously |



