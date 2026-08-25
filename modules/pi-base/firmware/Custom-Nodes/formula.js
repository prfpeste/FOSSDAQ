// Compiles a user-entered formula (variable: S = raw value) into a
// function (S) => number. No eval() on unknown input: only a character
// whitelist + identifier whitelist, then new Function() with exclusively
// Math functions in scope.
//
// Allowed: numbers, S, + - * / ^ ( ) , . whitespace, plus the Math
// function names listed below and PI/E. '^' is converted to '**' (power).
//
// Example: "5*(S+5)^3"

const ALLOWED_FUNCS = [
    'sqrt', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'atan2',
    'log', 'log10', 'log2', 'abs', 'pow', 'min', 'max',
    'floor', 'ceil', 'round', 'exp', 'sign', 'cbrt'
];

function compileFormula(expr) {
    if (typeof expr !== 'string' || expr.trim() === '') {
        expr = 'S';
    }
    expr = expr.trim();

    if (!/^[0-9A-Za-z_.,+\-*/^()\s]*$/.test(expr)) {
        throw new Error('Invalid characters in formula: "' + expr + '"');
    }

    const identifiers = expr.match(/[A-Za-z_]+/g) || [];
    identifiers.forEach(id => {
        if (id !== 'S' && id !== 'PI' && id !== 'E' && !ALLOWED_FUNCS.includes(id)) {
            throw new Error('Unknown identifier in formula: "' + id + '"');
        }
    });

    const jsExpr = expr.replace(/\^/g, '**');

    let fn;
    try {
        // eslint-disable-next-line no-new-func
        fn = new Function('S', 'Math',
            `"use strict"; const {${ALLOWED_FUNCS.join(',')}, PI, E} = Math; return (${jsExpr});`
        );
    } catch (err) {
        throw new Error('Could not parse formula: "' + expr + '" (' + err.message + ')');
    }

    return function(S) {
        const result = fn(S, Math);
        if (typeof result !== 'number' || isNaN(result)) {
            throw new Error('Formula "' + expr + '" did not return a valid number for S=' + S);
        }
        return result;
    };
}

module.exports = { compileFormula };
