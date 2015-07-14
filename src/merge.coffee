module.exports = (t, os...) -> t[k] = v for k,v of o when v != undefined for o in os; t
