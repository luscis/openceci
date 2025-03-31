package main

import (
	"flag"

	"github.com/luscis/libol"
	"github.com/luscis/openceci/pkg/config"
	"github.com/luscis/openceci/pkg/proxy"
)

func main() {
	mode := "http"
	conf := ""
	flag.StringVar(&mode, "mode", "http", "Proxy mode for http, socks or tcp")
	flag.StringVar(&conf, "conf", "ceci.yaml", "The configuration file")
	flag.Parse()

	libol.PreNotify()
	if mode == "http" {
		c := &config.HttpProxy{Conf: conf}
		if err := c.Initialize(); err != nil {
			return
		}
		p := proxy.NewHttpProxy(c)
		libol.Go(p.Start)
	} else if mode == "socks" {
		c := &config.SocksProxy{Conf: conf}
		if err := c.Initialize(); err != nil {
			return
		}
		p := proxy.NewSocksProxy(c)
		libol.Go(p.Start)
	} else {
		c := &config.TcpProxy{Conf: conf}
		if err := c.Initialize(); err != nil {
			return
		}
		p := proxy.NewTcpProxy(c)
		libol.Go(p.Start)
	}
	libol.SdNotify()
	libol.Wait()
}
