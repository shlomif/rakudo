## $Id$

=head1 TITLE

Signature - Perl 6 Signature class

=head1 DESCRIPTION

This file sets up the high level Perl 6 C<Signature> class. It wraps around a
P6LowLevelSig and provides higher level access to it.

=cut

.namespace ['Signature']

.sub 'onload' :anon :init :load
    .local pmc p6meta
    p6meta = get_hll_global ['Mu'], '$!P6META'
    p6meta.'new_class'('Signature', 'parent'=>'Cool', 'attr'=>'$!llsig $!param_cache $!arity $!count $!try_bind_sub $!bind_target')
.end


=head2 Methods

=over 4

=item arity()

Return the number of required parameters to the block.

=cut

.sub 'arity' :method
    self.'params'()
    $P0 = getattribute self, '$!arity'
    .return ($P0)
.end

=item count()

Return the number of allowed parameters to the block.

=cut

.sub 'count' :method
    self.'params'()
    $P0 = getattribute self, '$!count'
    .return ($P0)
.end


=item params

Returns a C<List> of C<Parameter> descriptors.

=cut

.sub 'params' :method
    # Did we compute this before?
    .local pmc result
    result = getattribute self, '$!param_cache'
    $I0 = defined result
    if $I0 goto have_result

  compute_result:
    # Create result.
    result = new ['Parcel']

    # Grab low level signature we're wrapping.
    .local pmc llsig
    llsig = getattribute self, '$!llsig'
    llsig = descalarref llsig

    # And Parameter proto.
    .local pmc parameter
    parameter = get_hll_global 'Parameter'

    # Loop over parameters.
    .local int cur_param, llsig_size, arity, count
    llsig_size = get_llsig_size llsig
    cur_param = -1
    arity = 0
    count = 0
  param_loop:
    inc cur_param
    unless cur_param < llsig_size goto param_done

    # Get all current parameter info.
    .local pmc nom_type, cons_type, names, type_captures, default, sub_sig
    .local int flags, optional, invocant, multi_invocant, slurpy, rw, parcel, capture, copy, named
    .local string name, coerce_to
    get_llsig_elem llsig, cur_param, name, flags, nom_type, cons_type, names, type_captures, default, sub_sig, coerce_to
    optional       = flags & SIG_ELEM_IS_OPTIONAL
    invocant       = flags & SIG_ELEM_INVOCANT
    multi_invocant = flags & SIG_ELEM_MULTI_INVOCANT
    slurpy         = flags & SIG_ELEM_SLURPY
    rw             = flags & SIG_ELEM_IS_RW
    copy           = flags & SIG_ELEM_IS_COPY
    parcel         = flags & SIG_ELEM_IS_PARCEL
    capture        = flags & SIG_ELEM_IS_CAPTURE

    # Ensure name isn't null.
    unless null name goto name_ok
    name = ''
  name_ok:

    # Make sure constraints is non-null.
    unless null cons_type goto have_cons
    cons_type = get_hll_global ['Bool'], 'True'
    goto cons_done
  have_cons:
    cons_type = '&flat'(cons_type :flat)
  cons_done:

    # Any names?
    named = 0
    if null names goto no_names
    named = 1
    names = '&flat'(names :flat)
    goto names_done
  no_names:
    names = '&flat'()
    $I0 = flags & SIG_ELEM_SLURPY_NAMED
    unless $I0 goto names_done
    named = 1
  names_done:

    # Any type captures?
    if null type_captures goto no_type_captures
    type_captures = '&flat'(type_captures :flat)
    goto type_captures_done
  no_type_captures:
    type_captures = '&flat'()
  type_captures_done:

    # Make sure default and sub-signature are non-null.
    unless null default goto default_done
    default = '!FAIL'()
  default_done:
    if null sub_sig goto no_sub_sig
    sub_sig = self.'new'('llsig'=>sub_sig)
    goto sub_sig_done
  no_sub_sig:
    sub_sig = '!FAIL'()
  sub_sig_done:

    # Create parameter instance.
    $P0 = parameter.'new'('name'=>name, 'type'=>nom_type, 'constraints'=>cons_type, 'optional'=>optional, 'slurpy'=>slurpy, 'invocant'=>invocant, 'multi_invocant'=>multi_invocant, 'rw'=>rw, 'parcel'=>parcel, 'capture'=>capture, 'copy'=>copy, 'named'=>named, 'named_names'=>names, 'type_captures'=>type_captures, 'default'=>default, 'signature'=>sub_sig)
    push result, $P0
    if slurpy goto param_slurpy
    inc count
    if optional goto param_loop
    inc arity
    goto param_loop
  param_slurpy:
    # Use a negative count to indicate infinity
    count = - llsig_size
    goto param_loop
  param_done:

    # Cache and return.
    setattribute self, '$!param_cache', result
    $P0 = box arity
    setattribute self, '$!arity', $P0
    $P0 = get_hll_global 'Inf'
    if count < 0 goto count_done
    $P0 = box count
  count_done:
    setattribute self, '$!count', $P0

  have_result:
    .return (result)
.end


=item !BIND

Binds the signature into the given bind target.

=cut

.sub '!BIND' :method
    .param pmc capture

    # Get hold of the bind testing sub.
    $P0 = getattribute self, '$!try_bind_sub'
    $I0 = defined $P0
    if $I0 goto have_try_bind_sub
    $P0 = self.'!make_try_bind_sub'()
  have_try_bind_sub:

    # Attempt to bind and get back a hash of the bound variables.
    .local pmc bound
    bound = $P0(capture)

    # Update the target.
    .local pmc target, bound_it
    target = getattribute self, '$!bind_target'
    $I0 = defined target
    unless $I0 goto done
    bound_it = iter bound
  bound_it_loop:
    unless bound_it goto bound_it_loop_end
    $S0 = shift bound_it
    $P0 = bound[$S0]
    target[$S0] = $P0
    goto bound_it_loop
  bound_it_loop_end:

  done:
    $P0 = get_hll_global 'True'
    .return ($P0)
.end


=item !make_try_bind_sub

This is terrifying. To try binding a signature, we want to have a sub so we
have a proper lex pad to bind against, and constraints will work. However,
it can't be the actual sub the signature is attached to, and we won't always
need it, So, we'll "just" manufacture one on demand.

=cut

.sub '!make_try_bind_sub' :method
    .local string pir

    # Opening.
    pir = <<'PIR'
.sub ''
    .param pmc capture
PIR

    # Generate code for parameter lexicals.
    pir = self.'!append_pir_for_sig_vars'(self, pir, 1)

    # Ending.
    pir = concat pir, <<'PIR'
    bind_llsig capture
    $P0 = getinterp
    $P0 = $P0['lexpad']
    .return ($P0)
.end
PIR

    # Compile and return.
    $P0 = compreg 'PIR'
    $P0 = $P0(pir)
    $P0 = $P0[0]
    $P1 = getattribute self, '$!llsig'
    $P1 = descalarref $P1
    setprop $P0, '$!llsig', $P1
    .return ($P0)
.end

.sub '!append_pir_for_sig_vars' :method
    .param pmc sig
    .param string pir
    .param int i

    # Go through params.
    .local pmc params, param_it
    params = sig.'params'()
    param_it = iter params
  it_loop:
    unless param_it goto it_loop_end
    $P0 = shift param_it

    # If we have a sub-signature, emit code for that.
    .local pmc sub_sig
    sub_sig = $P0.'signature'()
    $I0 = defined sub_sig
    unless $I0 goto no_sub_sig
    (pir, i) = self.'!append_pir_for_sig_vars'(sub_sig, pir, i)
  no_sub_sig:

    # Emit PIR for variable.
    $S0 = $P0.'name'()
    if null $S0 goto it_loop
    if $S0 == '' goto it_loop
    pir = concat pir, '    $P'
    $S1 = i
    pir = concat pir, $S1
    pir = concat pir, " = new ['ObjectRef']\n    .lex '"
    pir = concat pir, $S0
    pir = concat pir, "', $P"
    pir = concat pir, $S1
    pir = concat pir, "\n"
    inc i
    goto it_loop
  it_loop_end:

    .return (pir, i)
.end

=back

=cut

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
