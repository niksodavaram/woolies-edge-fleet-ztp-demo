# DDS ↔ MQTT Bridge Logic (Design)

```python
# Pseudo-code: DDS <-> MQTT bridge

def on_dds_update(sample):
    topic = f"store/{sample.store_id}/sensor/{sample.sensor_id}"
    payload = json.dumps({"value": sample.value, "ts": sample.timestamp})
    mqtt_client.publish(topic, payload, qos=1)

def on_mqtt_message(topic, payload):
    store_id, sensor_id = parse_topic(topic)
    msg = DdsSample(
        store_id=store_id,
        sensor_id=sensor_id,
        value=payload["value"],
        timestamp=payload["ts"],
    )
    dds_writer.write(msg)
```