"use strict";

module.exports = {
  public: true,
  host: "0.0.0.0",
  port: 9000,
  reverseProxy: true,
  maxHistory: 10000,
  https: {
    enable: false,
  },
  theme: "default",
  defaults: {
    name: "SDM",
    host: "ergo",
    port: 6667,
    password: "",
    tls: false,
    rejectUnauthorized: false,
    nick: "sdm_%%",
    username: "thelounge",
    realname: "The Lounge User",
    join: "#somdomato",
  },
};
