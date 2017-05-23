// Copyright 2017 Semmle Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.

/**
 * @name Race condition in socket authentication
 * @description Opening a socket after authenticating via a different channel may allow an attacker to connect to the port first.
 * @kind problem
 * @problem.severity warning
 * @precision medium
 * @tags security
 *       external/cwe/cwe-421
 */

import java
import semmle.code.java.security.DataFlow
import semmle.code.java.security.SensitiveActions
import semmle.code.java.controlflow.Dominance
import semmle.code.java.dataflow.Guards

abstract class ConnectionMethod extends Method {}

/*
 * Amongst the Java networking utilities, the `ServerSocket*` classes allow listening on a port.
 * By contrast, the `Socket*` classes require connection to a specific address.
 * 
 * Listening (server) sockets are much more vulnerable to an unexpected user taking the connection,
 * as the connection is initiated by the user. It would be possible to implement this attack on client
 * socket connections, but this would require MITM-ing the connection between the authentication of the
 * server and the opening of the alternate channel, which seems quite tricky.
 */

/**
 * The `accept` method on `ServerSocket`, which listens for a connection and returns when one has
 * been established.
 */
class ServerSocketAcceptMethod extends ConnectionMethod {
  ServerSocketAcceptMethod() {
    this.getName() = "accept"
    and
    this.getDeclaringType().hasQualifiedName("java.net", "ServerSocket")
  }
}

/**
 * The `accept` method on `ServerSocketChannel`, which listens for a connection and returns when one has
 * been established.
 */
class ServerSocketChannelAcceptMethod extends ConnectionMethod {
  ServerSocketChannelAcceptMethod() {
    this.getName() = "accept"
    and
    this.getDeclaringType().hasQualifiedName("java.nio.channels", "ServerSocketChannel")
  }
}

predicate controlledByAuth(Expr controlled, Expr condition) {
  exists(ConditionBlock b |
    condition = b.getCondition()
    and
    b.controls(controlled.getBasicBlock(), _)
    and
    condition.(MethodAccess).getMethod() instanceof AuthMethod
  )
}

/*
 * The approach here is to look for connections where the opening
 * of the connection is guarded by an authentication check.
 * While this is not exactly what we want to look for (we want to
 * look for the absence of authentication over the new channel):
 * - If you are authenticating over the new channel, then there is
 *   little point in authenticating again beforehand. So we can
 *   assume that these cases are likely to be disjoint.
 * - Spotting something that looks like an authentication check is
 *   a heuristic that tells us that this connection is meant to be
 *   authenticated. If we checked every connection, we would have
 *   no idea which ones were meant to be secure.
 */
from MethodAccess connection, Expr condition
where
  connection.getMethod() instanceof ConnectionMethod
  and
  controlledByAuth(connection, condition)
select connection,
  "This connection occurs after the authentication in $@, rather than authentication over the new connection.",
  condition, "this condition"