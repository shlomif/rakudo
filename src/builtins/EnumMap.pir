.namespace ['EnumMap']

.sub 'onload' :anon :load :init
    .local pmc p6meta, enummapproto
    p6meta = get_hll_global ['Mu'], '$!P6META'
    enummapproto = p6meta.'new_class'('EnumMap', 'parent'=>'Cool', 'does_role'=>'Associative', 'attr'=>'$!storage')
.end

.sub 'new' :method
    .param pmc values :named :slurpy

    setattribute self, '$!storage', values
    .return (self)
.end

.sub 'postcircumfix:<{ }>' :method :multi
    .param pmc key

    .local pmc self
    .local pmc return
    $P0 = getattribute self, '$!storage'
    $P1 = find_lex '$key'
    return = $P0[key]
    unless null return goto done
    return = new ['Proxy']
    setattribute return, '$!base', $P0
    setattribute return, '$!key', $P1
  done:
    .return (return)
.end

.sub 'elems' :method :multi
    $P0 = getattribute self, '$!storage'
    $I0 = elements $P0
    $P1 = box $I0
    .return ($P1)
.end
