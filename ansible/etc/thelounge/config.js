"use strict";

module.exports = {
  public: true,
  host: "127.0.0.1",
  port: 9000,
  reverseProxy: true,
  maxHistory: 10000,
  https: {
    enable: false,
  },
  theme: "default",
  defaults: {
    name: "SDM",
    host: "localhost",
    port: 6697,
    password: "",
    tls: true,
    rejectUnauthorized: false,
    nick: "sdm_%%",
    username: "thelounge",
    realname: "The Lounge User",
    join: "#somdomato",
  },
};
