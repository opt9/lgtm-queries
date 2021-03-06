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
 * @name Conflicting attributes in base classes
 * @description When a class subclasses multiple base classes and more than one base class defines the same attribute, attribute overriding may result in unexpected behavior by instances of this class.
 * @kind problem
 * @tags reliability
 *       maintainability
 *       modularity
 * @problem.severity warning
 * @sub-severity low
 * @precision high
 * @id py/conflicting-attributes
 */

import python

predicate does_nothing(PyFunctionObject f) {
    not exists(Stmt s | s.getScope() = f.getFunction() |
        not s instanceof Pass and not ((ExprStmt)s).getValue() = f.getFunction().getDocString()
    )
}

/* If a method performs a super() call then it is OK as the 'overridden' method will get called */
predicate calls_super(FunctionObject f) {
    exists(Call sup, Call meth, Attribute attr, GlobalVariable v | 
        meth.getScope() = f.getFunction() and
        meth.getFunc() = attr and
        attr.getObject() = sup and
        attr.getName() = f.getName() and
        sup.getFunc() = v.getAnAccess() and
        v.getId() = "super"
    )
}

from ClassObject c, ClassObject b1, ClassObject b2, string name,
int i1, int i2, Object o1, Object o2
where c.getBaseType(i1) = b1 and
c.getBaseType(i2) = b2 and 
i1 < i2 and o1 != o2 and
o1 = b1.lookupAttribute(name) and 
o2 = b2.lookupAttribute(name) and
not name.matches("\\_\\_%\\_\\_") and
not calls_super(o1) and
not does_nothing(o2) and
not o1.overrides(o2) and
not o2.overrides(o1) and
not c.declaresAttribute(name)

select c, "Base classes have conflicting values for attribute '" + name + "': $@ and $@.", o1, o1.toString(), o2, o2.toString()

