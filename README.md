# NeuronSimulator
A digital neuron simulation core written in SystemVerilog. Implements a time-multiplexed learning engine with Spike-Timing-Dependent Plasticity (STDP) and Short-Term Plasticity (STP), and features a configurable Leaky integrate-and-fire (TC-LIF) neuron model.

## Waveform 1 –> TC-LIF + STDP+STP Single Neuron Test (min_weight = 0):
<img width="1887" height="278" alt="Image" src="https://github.com/user-attachments/assets/1e340d15-e43a-4017-9367-6f02f33e0bcb" />
The neuron integrates presynaptic inputs in the dendritic compartment, producing burst-driven soma spikes. STP suppresses efficacy under high presynaptic firing, limiting output activity. With limited output spikes and an overabundance of pre-spikes, STDP applies an LTD event when the post-synaptic spike precedes the pre-synaptic spike, weakening the synaptic weight. Weights decay toward zero when overstimulated, maintaining stability and preventing runaway dynamics.

## Waveform 2 – TC-LIF + STDP+STP Single Neuron Test (min_weight = –1000):
<img width="1884" height="271" alt="Image" src="https://github.com/user-attachments/assets/6bca2538-3772-4730-88d6-59f6a9f971ab" />
The dendritic compartment continues to burst and drive the soma like in waveform 1, but with extended negative weight bounds, repeated presynaptic firing depletes synaptic efficacy through STP. Once fully expended, the negative weights no longer provide excitatory drive to the dendrite, effectively silencing the neuron. This behavior resembles excitotoxic-like shutdown, where overstimulation leads to a pathological loss of activity instead of stable adaptation.
