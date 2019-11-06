if [ -z $6 ]
then
  echo "please call $0 <name of new container> <distribution, eg. debian> <release, eg. jessie> <RAM in MB> <CPU cores> <DISK in GB>"
  exit 1
fi

NAME=$1
DIST=$2
RELEASE=$3
RAM=$4
CPU=$5
DISK=$6

echo "Create container"
lxc launch images:$DIST/$RELEASE $NAME
echo "Cointainer created"

sleep 1

RAW=""
IPV4=""
while [ ! -n "$RAW" ];
do
        RAW=$(lxc list --format csv -c sn4 |grep ",$NAME," |awk -F',' '{print $3}')
        echo "Waiting for setup LXC network..."
        sleep 1;
done
IPV4=$(echo $RAW | awk '{print $1}')

echo -e "\n\n"

echo "Setup config"
lxc config set $NAME limits.memory $RAM\MB
lxc config set $NAME limits.cpu $CPU
lxc config device add $NAME root disk path=/ pool=default size=$DISK\GB

sleep 1

echo "apt update; upgrade"
lxc exec $NAME -- /bin/bash -c "/usr/bin/apt-get -y update"
lxc exec $NAME -- /bin/bash -c "/usr/bin/apt-get -y upgrade"
sleep 1

echo "Install SSH server"
lxc exec $NAME -- /usr/bin/apt install -y openssh-server iputils-ping
sleep 1

echo "Setup root password"
PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')
lxc exec $NAME -- sh -c "echo \"root:$PASSWORD\" | chpasswd"

lxc exec $NAME -- sed -i 's/PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
lxc exec $NAME -- sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

lxc exec $NAME -- service sshd restart

echo -e "\n\nServer IP:\n\t$IPV4\n\nServer password:\n\t$PASSWORD\n\n"