package com.hortonworks.bolts;

import java.util.HashMap;
import java.util.Map;

import org.cometd.client.BayeuxClient;
import org.cometd.client.transport.ClientTransport;
import org.cometd.client.transport.LongPollingTransport;
import org.eclipse.jetty.client.HttpClient;

import com.hortonworks.events.DeviceStatus;
import com.hortonworks.events.STBStatus;
import com.hortonworks.util.Constants;

import backtype.storm.task.OutputCollector;
import backtype.storm.task.TopologyContext;
import backtype.storm.topology.OutputFieldsDeclarer;
import backtype.storm.topology.base.BaseRichBolt;
import backtype.storm.tuple.Fields;
import backtype.storm.tuple.Tuple;
import backtype.storm.tuple.Values;

public class PublishDeviceStatus extends BaseRichBolt {
	private String pubSubUrl = Constants.pubSubUrl;
	private String deviceChannel = Constants.deviceChannel;
	private BayeuxClient bayuexClient;
	private OutputCollector collector;
	
	public void execute(Tuple tuple) {
		STBStatus deviceStatus = (STBStatus) tuple.getValueByField("DeviceStatus");
		
		Map<String, Object> data = new HashMap<String, Object>();
		data.put("deviceSerialNumber", deviceStatus.getSerialNumber());
		data.put("internalTemp", deviceStatus.getInternalTemp());
		data.put("signalStrength", deviceStatus.getSignalStrength());
		data.put("deviceModel", deviceStatus.getDeviceModel());
		data.put("latitude", deviceStatus.getLatitude());
		data.put("longitude", deviceStatus.getLongitude());
		data.put("status", deviceStatus.getStatus());
		data.put("state", deviceStatus.getState());
		bayuexClient.getChannel(deviceChannel).publish(data);
		
		collector.emit(tuple, new Values((DeviceStatus)deviceStatus));
		collector.ack(tuple);
	}

	public void prepare(Map arg0, TopologyContext arg1, OutputCollector collector) {
		this.collector = collector;
		
		HttpClient httpClient = new HttpClient();
		try {
			httpClient.start();
		} catch (Exception e) {
			e.printStackTrace();
		}

		// Prepare the transport
		Map<String, Object> options = new HashMap<String, Object>();
		ClientTransport transport = new LongPollingTransport(options, httpClient);

		// Create the BayeuxClient
		bayuexClient = new BayeuxClient(pubSubUrl, transport);
		
		bayuexClient.handshake();
		boolean handshaken = bayuexClient.waitFor(3000, BayeuxClient.State.CONNECTED);
		if (handshaken)
		{
			System.out.println("Connected to Cometd Http PubSub Platform");
		}
		else{
			System.out.println("Could not connect to Cometd Http PubSub Platform");
		}
	}

	public void declareOutputFields(OutputFieldsDeclarer declarer) {
		declarer.declare(new Fields("DeviceStatus"));
	}
}