## Usage instructions

Export your kubeconfig, specify the node name and the process ID of the DPDK process that's running on the CPUs that
you want to investigate. Then, run `oc adm must-gather` with the following commands:
~~~
export KUBECONFIG=<path to your kubeconfig>
NODE_NAME=<node>
PROCESS=<pid or process name>
oc adm must-gather --image=quay.io/akaris/must-gather-pmd:v0.1 --node-name=${NODE_NAME} -- gather ${PROCESS}
~~~

For example:
~~~
oc adm must-gather --image=quay.io/akaris/must-gather-pmd:v0.1 --node-name=worker1 -- gather dpdk-testpmd
~~~
