#!/bin/bash
# Author: Andreas Karis <ak.karis@gmail.com, akaris@redhat.com>
# A lot of the commands in this script are based on https://github.com/karampok/snife/blob/main/bin/dpdk-prof.sh

set -eux

VERBOSE=true
HOST_PATH="/host"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_COLLECTION_PATH="data-store"
LOG_PATH="${BASE_COLLECTION_PATH}/pmd_logs"
mkdir -p "${LOG_PATH}"
cd "${LOG_PATH}"

# verbose can be enabled or disabled on demand
verbose () {
  [[ "${VERBOSE}" ]] && echo "$@" >&2
}

# get_pid returns the provided parameter as is if it is a number. Otherwise it will try to find the process ID of the
# provided process.
get_pid() {
  verbose "Getting process PID for ${1}"
  local parameter="${1}"
  local pid="${parameter}"
  local re='^[0-9]+$'
  if ! [[ $parameter =~ $re ]] ; then
    pid=$(pidof -s "${parameter}")
  fi
  echo "${pid}"
}

# get_process_cpus returns the CPUs that this process and its children are running on in the format "1 2 5 7 12".
# See: https://stackoverflow.com/questions/50430036/how-can-a-linux-cpuset-be-iterated-over-with-shell
get_process_cpus() {
  verbose "Getting CPUs for PID ${1}"
  local pid="${1}"
  local cgroup
  cgroup=$(cat "${HOST_PATH}/proc/${pid}/cpuset")
  local cpuset
  cpuset=$(cat "${HOST_PATH}/sys/fs/cgroup/cpuset/${cgroup}/cpuset.cpus")
  local cpus
  cpus=$(echo "${cpuset}" | awk '/-/{for (i=$1; i<=$2; i++)printf "%s%s",i,ORS;next} 1' ORS=' ' RS=, FS=-)
  echo "${cpus}"
}

# collect_ftrace_events collects the ftrace events on the provided list of CPUs.
collect_ftrace_events() {
  verbose "Getting ftrace events for CPUs $*"
  local dir=ftrace_events
  mkdir -p "${dir}"
  echo sched irq_vectors > "${HOST_PATH}/sys/kernel/debug/tracing/set_event"
  echo 1 > "${HOST_PATH}/sys/kernel/debug/tracing/tracing_on" && sleep 10 && echo 0 > \
      "${HOST_PATH}/sys/kernel/debug/tracing/tracing_on"
  for c in "$@";do
    cat "${HOST_PATH}/sys/kernel/debug/tracing/per_cpu/cpu${c}/trace" > "${dir}/cpu${c}.txt"
  done
  echo > "${HOST_PATH}/sys/kernel/debug/tracing/set_event"
}

# collect_ftrace_events collects the ftrace stacktrace for sched_switch events.
collect_ftrace_sched_switch_stacktrace() {
  verbose "Getting ftrace events for CPUs $*"
  local dir=ftrace_sched_switch_stacktrace
  mkdir -p "${dir}"
  echo 'stacktrace' > "${HOST_PATH}/sys/kernel/debug/tracing/events/sched/sched_switch/trigger"
  echo 1 > "${HOST_PATH}/sys/kernel/debug/tracing/tracing_on" && sleep 10 && echo 0 > \
      "${HOST_PATH}/sys/kernel/debug/tracing/tracing_on"
  for c in "$@";do
    cat "${HOST_PATH}/sys/kernel/debug/tracing/per_cpu/cpu${c}/trace" > "${dir}/cpu${c}.txt"
  done
  echo '!stacktrace' > "${HOST_PATH}/sys/kernel/debug/tracing/events/sched/sched_switch/trigger"
}

# collect_ftrace_function_graphs collects the ftrace function graph on the provided list of CPUs.
collect_ftrace_function_graphs() {
  verbose "Getting ftrace function graphs for CPUs $*"
  local dir=ftrace_function_graphs
  mkdir -p "${dir}"
  echo function_graph > "${HOST_PATH}/sys/kernel/debug/tracing/current_tracer"
  echo 1 > "${HOST_PATH}/sys/kernel/debug/tracing/tracing_on" && sleep 10 && echo 0 > \
      "${HOST_PATH}/sys/kernel/debug/tracing/tracing_on"
  for c in "$@";do
    cat "${HOST_PATH}/sys/kernel/debug/tracing/per_cpu/cpu${c}/trace" > "${dir}/cpu${c}.txt"
  done
  echo nop > "${HOST_PATH}/sys/kernel/debug/tracing/current_tracer"
}

collect_perf() {
  verbose "Running perf for CPUs $*"
  local dir=perf
  mkdir -p "${dir}"
  pushd "${dir}"
  comma_separated_cpus=$(echo "$@" | sed 's/ /,/g')
  perf record -z -C "${comma_separated_cpus}" sleep 10 &> /dev/null
  for cpu in "$@";do
    perf report -C "${cpu}" | cat &> "report_cpu_${cpu}.output"
  done
  perf report --sort=comm,dso | cat &> report_sort_comm_dso.output
  perf report | cat &> report_stdio.output
  popd
}

collect_cpupower() {
  local dir=cpupower
  mkdir -p "${dir}"
  cpupower monitor -i 10 | cat &> "${dir}/cpu_monitor.output"
}

collect_top() {
  local pid="${1}"
  local dir=top
  mkdir -p "${dir}"
  top -b -n 2 -H -p "${pid}" | cat &> "${dir}/top.output"
}

collect_pcm() {
  local pid="${1}"
  local dir=pcm
  mkdir -p "${dir}"
  verbose "Collecting PCM information and storing it in ${dir}"
  pcm 1 -i=10 -f | cat &> "${dir}/pcm_1_-i=10"
  pcm 1 -i=10 -f -pid "${pid}" | cat &> "${dir}/pcm_1_-i=10_-f_-pid_${pid}"
}

collect_sys_proc_etc() {
  local pid="${1}"
  local sub_dir="${2}"
  local dir="sys_proc/${sub_dir}"
  verbose "Collecting relevant data from /sys and /proc and storing it in ${dir}"
  mkdir -p "${dir}"
  cat /host/proc/interrupts > "${dir}/interrupts"
  cat /host/proc/iomem > "${dir}/iomem"
  cat /host/proc/sched_debug > "${dir}/sched_debug"
  dmesg > "${dir}/dmesg"
  sysctl -A > "${dir}/sysctl_-A"
  ps -T -p "${pid}" | tail -n+2 | while read -r line; do
    ppid=$(echo "${line}" | awk '{print $2}')
    echo -n "${line} "; taskset -c -p "${ppid}"
  done > "${dir}/ps_-T_-p_${pid}_pipe_taskset_-c_-p_ppid"
  # ps -ae -o pid= | xargs -n 1 taskset -cp > "${dir}/ps_-ae_-o_pid=_xargs_-n_1_taskset_-cp"
  ps -eo pid,tid,class,rtprio,ni,pri,psr,pcpu,stat,wchan:14,comm,cls > \
      "${dir}/ps_-eo_pid_tid_class_rtprio_ni_pri_psr_pcpu_stat_wchan_comm_cls"
  pstree -p "${pid}" > "${dir}/pstree_p_${pid}"
  ip -s -s --json link > "${dir}/ip_-s_-s_--json_link"
  numastat -m -n -v > "${dir}/numastat_-m_-n_-v"
  numastat -m -n -v -p "${pid}" > "${dir}/numastat_-m_-n_-v_-p_${pid}"
  numactl -show > "${dir}/numactl_-show"
  numactl --hardware > "${dir}/numactl_--hardware"
}

process="${PROCESS:-}"
if [ "${process}" == "" ]; then
    verbose "Please provide a process ID or process name via environment variable PROCESS."
    exit 1
fi
pid=$(get_pid "${process}")
cpus=$(get_process_cpus "${pid}")
collect_ftrace_events ${cpus}
collect_ftrace_sched_switch_stacktrace ${cpus}
collect_ftrace_function_graphs ${cpus}
collect_perf ${cpus}
collect_top "${pid}"
# collect_pcm "${pid}"

# Collect various interface counters and counters from /sys, /proc 10 seconds apart.
# Calculate delta for interface counters.
first_sample="before"
second_sample="after"
sleep_interval=10
collect_sys_proc_etc "${pid}" "${first_sample}" && sleep "${sleep_interval}" && collect_sys_proc_etc "${pid}" "${second_sample}"
python "${SCRIPT_DIR}"/ip_link_delta.py "sys_proc/${first_sample}/ip_-s_-s_--json_link" "sys_proc/${second_sample}/ip_-s_-s_--json_link" "${sleep_interval}" > sys_proc/interface_counters_delta.txt
