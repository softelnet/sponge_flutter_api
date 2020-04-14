// Copyright 2018 The Sponge authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

class SpongeConnection implements Comparable {
  SpongeConnection({
    this.name,
    this.url,
    this.username,
    this.password,
    this.anonymous,
    this.savePassword = true,
    this.network,
    this.subscribe = false,
    List<String> subscriptionEventNames,
  }) : subscriptionEventNames = subscriptionEventNames ?? [];

  String name;
  String url;
  String username;
  String password;
  bool anonymous;
  bool savePassword;
  String network;
  bool subscribe;
  List<String> subscriptionEventNames;

  factory SpongeConnection.of(SpongeConnection other) => SpongeConnection(
        name: other.name,
        url: other.url,
        username: other.username,
        password: other.password,
        anonymous: other.anonymous,
        savePassword: other.savePassword,
        network: other.network,
        subscribe: other.subscribe,
        subscriptionEventNames: other.subscriptionEventNames?.toList(),
      );

  @override
  int compareTo(other) => name.compareTo(other.name);

  bool isSame(SpongeConnection connection) {
    return name == connection?.name &&
        url == connection?.url &&
        username == connection?.username &&
        password == connection?.password &&
        anonymous == connection?.anonymous &&
        network == connection?.network;
  }

  void setFrom(SpongeConnection connection) {
    name = connection.name;
    url = connection.url;
    username = connection.username;
    password = connection.password;
    anonymous = connection.anonymous;
    savePassword = connection.savePassword;
    network = connection.network;
    subscribe = connection.subscribe;
    subscriptionEventNames = connection.subscriptionEventNames?.toList();
  }

  bool isSecure() => url != null && url.toLowerCase().startsWith('https');
}

class NetworkStatus {
  NetworkStatus(this.name, this.isLocal);

  final String name;
  final bool isLocal;
}
