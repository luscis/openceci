module github.com/luscis/openceci

go 1.16

replace (
	golang.org/x/crypto => github.com/golang/crypto v0.0.0-20200604202706-70a84ac30bf9
	golang.org/x/net => github.com/golang/net v0.0.0-20190812203447-cdfb69ac37fc
	golang.org/x/sys => github.com/golang/sys v0.0.0-20190209173611-3b5209105503
	golang.org/x/time => github.com/golang/time v0.0.0-20210220033141-f8bda1e9f3ba
)

exclude github.com/sirupsen/logrus v1.8.1

require (
	github.com/coreos/go-systemd/v22 v22.3.2 // indirect
	github.com/go-ldap/ldap v3.0.3+incompatible // indirect
	github.com/gorilla/mux v1.8.0
	github.com/luscis/libol v0.0.0-20250331032641-e685f5691d61
	github.com/vishvananda/netlink v1.1.0 // indirect
	github.com/xtaci/kcp-go/v5 v5.6.1 // indirect
	golang.org/x/net v0.0.0-20210525063256-abc453219eb5
	golang.org/x/sys v0.0.0-20210823070655-63515b42dcdf // indirect
	gopkg.in/asn1-ber.v1 v1.0.0-20181015200546-f715ec2f112d // indirect
	gopkg.in/yaml.v2 v2.4.0
)
