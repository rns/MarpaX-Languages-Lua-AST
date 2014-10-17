
call metalua lua5.1-ast-tests\%1 -a +x 2>&1 > lua5.1-ast-tests\%1.ast

call metalua lua5.1-tests\%1 -a +x 2>&1 > lua5.1-tests\%1.ast

diff lua5.1-tests\%1.ast lua5.1-ast-tests\%1.ast > %1.ast.diff

less %1.ast.diff


