# Oracle

### install instant client

### build xo 

go build -tags oracle -o xo main.go

### test
export LD_LIBRARY_PATH=your_instantclient_12_2_path
export PKG_CONFIG_PATH=$GOPATH/src/github.com/xo/xo/contrib

xo --escape-all 'oci8://c##admin/password@127.0.0.1:1521/ORCLCDB' -o $GOPATH/src/github.com/xo/xo/examples/booktest/oracle/models --template-path=$GOPATH/src/github.com/xo/xo/templates --package models
