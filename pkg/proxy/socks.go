package proxy

import (
	"crypto/tls"
	"time"

	"github.com/luscis/libol"
	co "github.com/luscis/openceci/pkg/config"
	ss "github.com/luscis/openceci/pkg/socks5"
)

type SocksProxy struct {
	server *ss.Server
	out    *libol.SubLogger
	cfg    *co.SocksProxy
}

func NewSocksProxy(cfg *co.SocksProxy) *SocksProxy {
	s := &SocksProxy{
		cfg: cfg,
		out: libol.NewSubLogger(cfg.Listen),
	}
	// Create a SOCKS5 server
	user, pass := co.SplitSecret(cfg.Secret)
	authMethods := make([]ss.Authenticator, 0, 2)
	if user != "" {
		author := ss.UserPassAuthenticator{
			Credentials: ss.StaticCredentials{
				user: pass,
			},
		}
		authMethods = append(authMethods, author)
		s.out.Debug("SocksProxy: Auth user %s", user)
	}
	conf := &ss.Config{
		Backends:    cfg.Backends,
		AuthMethods: authMethods,
		Logger:      s.out,
	}
	crt := cfg.Cert
	if crt != nil && crt.KeyFile != "" {
		conf.TlsConfig = &tls.Config{
			Certificates: crt.GetCertificates(),
		}
	}
	server, err := ss.New(conf)
	if err != nil {
		s.out.Error("NewSocksProxy %s", err)
		return nil
	}
	s.server = server
	return s
}

func (s *SocksProxy) Start() {
	if s.server == nil || s.cfg == nil {
		return
	}
	addr := s.cfg.Listen

	crt := s.cfg.Cert
	if crt == nil || crt.KeyFile == "" {
		s.out.Info("SocksProxy.Start: socks5://%s", s.cfg.Listen)
	} else {
		s.out.Info("SocksProxy.Start: sockss://%s", s.cfg.Listen)
	}

	promise := &libol.Promise{
		First:  time.Second * 2,
		MaxInt: time.Minute,
		MinInt: time.Second * 10,
	}
	promise.Go(func() error {
		if err := s.server.ListenAndServe("tcp", addr); err != nil {
			s.out.Warn("SocksProxy.Start %s", err)
			return err
		}
		return nil
	})
}
