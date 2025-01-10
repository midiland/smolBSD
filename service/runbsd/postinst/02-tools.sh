#!/bin/sh

# script to use /etc/rc.d as runit run/finish

cat >bin/rcd2run.sh<<EOF
#!/bin/sh
exec 2>&1

DIR_PATH=\$(pwd)
PROG_NAME=\$(basename "\$0")
SERVICE_NAME=\$(basename "\$DIR_PATH")

case "\$PROG_NAME" in
run)
        ACTION="start"
        ;;
finish)
        ACTION="stop"
        ;;
*)
        echo "unsupported"
        exit 1
        ;;
esac

exec /etc/rc.d/"\$SERVICE_NAME" "\$ACTION"
EOF
chmod +x bin/rcd2run.sh
