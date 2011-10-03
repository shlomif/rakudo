# Here we start to piece together the top of the object model hierarchy.
# We can't just declare these bits in CORE.setting with normal Perl 6
# syntax due to circularity issues. Note that we don't compose any of
# these - which is equivalent to a { ... } body.
#
# One particular circularity we break here is that you can't have
# inheritance in Perl 6 without traits, but that needs multiple
# dispatch, which can't function without some a type hierarchy in
# place. It also needs us to be able to declare a signature with
# parameters and a code objects with dispatchees, which in turn need
# attributes. So, we set up quite a few bits in here, though the aim
# is to keep it "lagom". :-)
#
# Note that we do pay the cost of doing this every startup *for now*.
# In the medium term, we'll have bounded serialization. Then we'll likley
# do all of this in a BEGIN block and it'll get serialized and thus loading
# it will just be deserialization - hopefully! :) Note that said BEGIN will
# likely end up being in the setting itself, not in here, also.

# Bootstrapping Attribute class that we eventually replace with the read
# one.
my class BOOTSTRAPATTR {
    has $!name;
    has $!type;
    has $!box_target;
    method name() { $!name }
    method type() { $!type }
    method box_target() { $!box_target }
    method has_accessor() { 0 }
    method has-accessor() { 0 }
    method build() { }
    method is_generic() { $!type.HOW.archetypes.generic }
    method instantiate_generic($type_environment) {
        my $ins := $!type.HOW.instantiate_generic($!type, $type_environment);
        self.new(:name($!name), :box_target($!box_target), :type($ins))
    }
    method compose($obj) { }
}

# Set package type for auto-viv when needed.
pir::perl6_set_type_packagehow__vP(Perl6::Metamodel::PackageHOW);

# class Mu { ... }
my stub Mu metaclass Perl6::Metamodel::ClassHOW { ... };
Mu.HOW.add_parrot_vtable_mapping(Mu, 'get_integer',
    sub ($self) {
        nqp::unbox_i($self.Int())
    });
Mu.HOW.add_parrot_vtable_mapping(Mu, 'get_number',
    sub ($self) {
        nqp::unbox_n($self.Num())
    });
Mu.HOW.add_parrot_vtable_mapping(Mu, 'get_string',
    sub ($self) {
        nqp::unbox_s($self.Str())
    });
Mu.HOW.add_parrot_vtable_mapping(Mu, 'defined',
    sub ($self) { pir::istrue__IP($self.defined()) });

# class Any is Mu { ... }
my stub Any metaclass Perl6::Metamodel::ClassHOW { ... };
Any.HOW.add_parent(Any, Mu);
Perl6::Metamodel::ClassHOW.set_default_parent_type(Any);
pir::perl6_set_types_mu_any__vP(Mu, Any);

# class Cool is Any { ... }
my stub Cool metaclass Perl6::Metamodel::ClassHOW { ... };
Cool.HOW.add_parent(Cool, Any);

# class Attribute {
#     has str $!name;
#     has int $!rw;
#     has int $!has_accessor;
#     has $!type;
#     has $!container_descriptor;
#     has $!auto_viv_container;
#     has $!build_closure;
#     has $!package;
#     ... # Uncomposed
# }
my stub Attribute metaclass Perl6::Metamodel::ClassHOW { ... };
Attribute.HOW.add_parent(Attribute, Any);
Attribute.HOW.add_attribute(Attribute, BOOTSTRAPATTR.new(:name<$!name>, :type(str)));
Attribute.HOW.add_attribute(Attribute, BOOTSTRAPATTR.new(:name<$!rw>, :type(int)));
Attribute.HOW.add_attribute(Attribute, BOOTSTRAPATTR.new(:name<$!ro>, :type(int)));
Attribute.HOW.add_attribute(Attribute, BOOTSTRAPATTR.new(:name<$!has_accessor>, :type(int)));
Attribute.HOW.add_attribute(Attribute, BOOTSTRAPATTR.new(:name<$!type>, :type(Mu)));
Attribute.HOW.add_attribute(Attribute, BOOTSTRAPATTR.new(:name<$!container_descriptor>, :type(Mu)));
Attribute.HOW.add_attribute(Attribute, BOOTSTRAPATTR.new(:name<$!auto_viv_container>, :type(Mu)));
Attribute.HOW.add_attribute(Attribute, BOOTSTRAPATTR.new(:name<$!build_closure>, :type(Mu)));
Attribute.HOW.add_attribute(Attribute, BOOTSTRAPATTR.new(:name<$!package>, :type(Mu)));
Attribute.HOW.publish_parrot_vtable_mapping(Attribute);

# XXX Need new and accessor methods for Attribute in here for now.
Attribute.HOW.add_method(Attribute, 'new',
    sub ($self, :$name, :$type, :$container_descriptor, :$has_accessor, :$package, *%other) {
        my $attr := pir::repr_instance_of__PP($self);
        pir::repr_bind_attr_str__vPPsS($attr, Attribute, '$!name', $name);
        pir::setattribute__vPPsP($attr, Attribute, '$!type', $type);
        pir::repr_bind_attr_int__vPPsI($attr, Attribute, '$!has_accessor', $has_accessor);
        pir::setattribute__vPPsP($attr, Attribute, '$!container_descriptor', $container_descriptor);
        pir::setattribute__vPPsP($attr, Attribute, '$!package', $package);
        if pir::exists(%other, 'auto_viv_container') {
            pir::setattribute__vPPsP($attr, Attribute, '$!auto_viv_container',
                %other<auto_viv_container>);
        }
        $attr
    });
Attribute.HOW.add_method(Attribute, 'name', sub ($self) {
        pir::repr_get_attr_str__SPPs(pir::perl6_decontainerize__PP($self),
            Attribute, '$!name');
    });
Attribute.HOW.add_method(Attribute, 'type', sub ($self) {
        pir::getattribute__PPPs(pir::perl6_decontainerize__PP($self),
            Attribute, '$!type');
    });
Attribute.HOW.add_method(Attribute, 'container_descriptor', sub ($self) {
        pir::getattribute__PPPs(pir::perl6_decontainerize__PP($self),
            Attribute, '$!container_descriptor');
    });
Attribute.HOW.add_method(Attribute, 'auto_viv_container', sub ($self) {
        pir::getattribute__PPPs(pir::perl6_decontainerize__PP($self),
            Attribute, '$!auto_viv_container');
    });
Attribute.HOW.add_method(Attribute, 'has_accessor', sub ($self) {
        pir::perl6_booleanize__PI(
            pir::repr_get_attr_int__IPPs(pir::perl6_decontainerize__PP($self),
                Attribute, '$!has_accessor'));
    });
Attribute.HOW.add_method(Attribute, 'rw', sub ($self) {
        pir::perl6_booleanize__PI(
            pir::repr_get_attr_int__IPPs(pir::perl6_decontainerize__PP($self),
                Attribute, '$!rw'));
    });
Attribute.HOW.add_method(Attribute, 'set_rw', sub ($self) {
        pir::repr_bind_attr_int__vPPsi(pir::perl6_decontainerize__PP($self),
            Attribute, '$!rw', 1);
        pir::perl6_booleanize__PI(1)
    });
Attribute.HOW.add_method(Attribute, 'set_readonly', sub ($self) {
        pir::repr_bind_attr_int__vPPsi(pir::perl6_decontainerize__PP($self),
            Attribute, '$!ro', 1);
        pir::perl6_booleanize__PI(1)
    });
Attribute.HOW.add_method(Attribute, 'default_to_rw', sub ($self) {
        my $dcself := pir::perl6_decontainerize__PP($self);
        unless pir::repr_get_attr_int__iPPs($dcself, Attribute, '$!ro') {
            pir::repr_bind_attr_int__vPPsi($dcself, Attribute, '$!rw', 1);
        }
        pir::perl6_booleanize__PI(1)
    });
Attribute.HOW.add_method(Attribute, 'set_build', sub ($self, $closure) {
        pir::setattribute__0PPsP(pir::perl6_decontainerize__PP($self),
            Attribute, '$!build_closure', $closure);
    });
Attribute.HOW.add_method(Attribute, 'build', sub ($self) {
        pir::getattribute__PPPs(pir::perl6_decontainerize__PP($self),
            Attribute, '$!build_closure');
    });
Attribute.HOW.add_method(Attribute, 'is_generic', sub ($self) {
        my $dcself   := pir::perl6_decontainerize__PP($self);
        my $type := pir::getattribute__PPPs(pir::perl6_decontainerize__PP($dcself),
            Attribute, '$!type');
        my $build := pir::getattribute__PPPs(pir::perl6_decontainerize__PP($dcself),
            Attribute, '$!build_closure');
        pir::perl6_booleanize__PI($type.HOW.archetypes.generic || pir::defined__IP($build));
    });
Attribute.HOW.add_method(Attribute, 'instantiate_generic', sub ($self, $type_environment) {
        my $dcself   := pir::perl6_decontainerize__PP($self);
        my $type     := pir::getattribute__PPPs($dcself, Attribute, '$!type');
        my $cd       := pir::getattribute__PPPs($dcself, Attribute, '$!container_descriptor');
        my $pkg      := pir::getattribute__PPPs($dcself, Attribute, '$!package');
        my $avc      := pir::getattribute__PPPs($dcself, Attribute, '$!auto_viv_container');
        my $bc       := pir::getattribute__PPPs($dcself, Attribute, '$!build_closure');
        my $ins      := pir::repr_clone__PP($dcself);
        if $type.HOW.archetypes.generic {
            pir::setattribute__vPPsP($ins, Attribute, '$!type',
                $type.HOW.instantiate_generic($type, $type_environment));
            pir::setattribute__vPPsP($ins, Attribute, '$!package',
                $pkg.HOW.instantiate_generic($pkg, $type_environment));
            my $cd_ins := $cd.instantiate_generic($type_environment);
            pir::setattribute__vPPsP($ins, Attribute, '$!container_descriptor', $cd_ins);
            my $avc_copy := pir::repr_clone__PP(pir::perl6_var__PP($avc));
            pir::setattribute__vPPsP($ins, Attribute, '$!auto_viv_container',
                pir::setattribute__0PPsP($avc_copy, (pir::perl6_var__PP($avc_copy)).WHAT, '$!descriptor', $cd_ins));
        }
        if pir::defined__IP($bc) {
            pir::setattribute__vPPsP($ins, Attribute, '$!build_closure', $bc.clone());
        }
        $ins
    });

# class Scalar is Any {
#     has $!descriptor;
#     has $!value;
#     ...
# }
my stub Scalar metaclass Perl6::Metamodel::ClassHOW { ... };
Scalar.HOW.add_parent(Scalar, Any);
Scalar.HOW.add_attribute(Scalar, BOOTSTRAPATTR.new(:name<$!descriptor>, :type(Mu)));
Scalar.HOW.add_attribute(Scalar, BOOTSTRAPATTR.new(:name<$!value>, :type(Mu)));
Scalar.HOW.add_attribute(Scalar, BOOTSTRAPATTR.new(:name<$!whence>, :type(Mu)));
Scalar.HOW.add_method(Scalar, 'is_generic', sub ($self) {
    my $dcself := pir::perl6_decontainerize__PP($self);
    nqp::getattr($dcself, Scalar, '$!descriptor').is_generic()
});
Scalar.HOW.add_method(Scalar, 'instantiate_generic', sub ($self, $type_environment) {
    my $dcself := pir::perl6_decontainerize__PP($self);
    nqp::bindattr($dcself, Scalar, '$!descriptor',
        nqp::getattr($dcself, Scalar, '$!descriptor').instantiate_generic(
            $type_environment));
    my $val := nqp::getattr($dcself, Scalar, '$!value');
    if $val.HOW.archetypes.generic {
        nqp::bindattr($dcself, Scalar, '$!value',
            $val.HOW.instantiate_generic($val, $type_environment));
    }
    $self
});
pir::set_scalar_container_type__vP(Scalar);

# Scalar needs to be registered as a container type.
pir::set_container_spec__vPPsP(Scalar, Scalar, '$!value', pir::null__P());

# Helper for creating a scalar attribute. Sets it up as a real Perl 6
# Attribute instance, complete with container desciptor and auto-viv
# container.
sub scalar_attr($name, $type) {
    my $cd := Perl6::Metamodel::ContainerDescriptor.new(
        :of($type), :rw(1), :name($name));
    my $scalar := pir::repr_instance_of__PP(Scalar);
    pir::setattribute__vPPsP($scalar, Scalar, '$!descriptor', $cd);
    pir::setattribute__vPPsP($scalar, Scalar, '$!value', $type);
    return Attribute.new( :name($name), :type($type),
        :container_descriptor($cd), :auto_viv_container($scalar));
}
    
# class Signature {
#    has $!params;
#    has $!returns;
#    has $!arity;
#    has $!count;
#     ... # Uncomposed
# }
my stub Signature metaclass Perl6::Metamodel::ClassHOW { ... };
Signature.HOW.add_parent(Signature, Any);
Signature.HOW.add_attribute(Signature, BOOTSTRAPATTR.new(:name<$!params>, :type(Mu)));
Signature.HOW.add_attribute(Signature, BOOTSTRAPATTR.new(:name<$!returns>, :type(Mu)));
Signature.HOW.add_attribute(Signature, BOOTSTRAPATTR.new(:name<$!arity>, :type(Mu)));
Signature.HOW.add_attribute(Signature, BOOTSTRAPATTR.new(:name<$!count>, :type(Mu)));
Signature.HOW.add_method(Signature, 'is_generic', sub ($self) {
        # If any parameter is generic, so are we.
        my @params := pir::getattribute__PPPs($self, Signature, '$!params');
        for @params {
            my $is_generic := $_.is_generic();
            if $is_generic { return $is_generic }
        }
        return pir::perl6_booleanize__PI(0);
    });
Signature.HOW.add_method(Signature, 'instantiate_generic', sub ($self, $type_environment) {
        # Go through parameters, builidng new list. If any
        # are generic, instantiate them. Otherwise leave them
        # as they are.
        my $ins    := pir::repr_clone__PP($self);
        my @params := pir::getattribute__PPPs($self, Signature, '$!params');
        my @ins_params;
        for @params {
            if $_.is_generic() {
                @ins_params.push($_.instantiate_generic($type_environment))
            }
            else {
                @ins_params.push($_);
            }
        }
        pir::setattribute__0PPsP($ins, Signature, '$!params', @ins_params)
    });
Signature.HOW.add_method(Signature, 'set_returns', sub ($self, $type) {
        nqp::bindattr(pir::perl6_decontainerize__PP($self),
            Signature, '$!returns', pir::perl6_decontainerize__PP($type));
    });
    
# class Parameter {
#     has str $!variable_name
#     has $!named_names
#     has $!type_captures
#     has int $!flags
#     has $!nominal_type
#     has $!post_constraints
#     has $!coerce_type
#     has str $!coerce_method
#     has $!sub_signature
#     has $!default_value
#     has $!container_descriptor;
#     has $!attr_package;
#     ... # Uncomposed
# }
my stub Parameter metaclass Perl6::Metamodel::ClassHOW { ... };
Parameter.HOW.add_parent(Parameter, Any);
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!variable_name>, :type(str)));
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!named_names>, :type(Mu)));
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!type_captures>, :type(Mu)));
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!flags>, :type(int)));
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!nominal_type>, :type(Mu)));
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!post_constraints>, :type(Mu)));
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!coerce_type>, :type(Mu)));
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!coerce_method>, :type(str)));
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!sub_signature>, :type(Mu)));
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!default_value>, :type(Mu)));
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!container_descriptor>, :type(Mu)));
Parameter.HOW.add_attribute(Parameter, BOOTSTRAPATTR.new(:name<$!attr_package>, :type(Mu)));
Parameter.HOW.add_method(Parameter, 'is_generic', sub ($self) {
        # If nonimnal type is generic, so are we.
        my $type := pir::getattribute__PPPs($self, Parameter, '$!nominal_type');
        pir::perl6_booleanize__PI($type.HOW.archetypes.generic)
    });
my $SIG_ELEM_IS_RW           := 256;
my $SIG_ELEM_IS_COPY         := 512;
my $SIG_ELEM_IS_OPTIONAL     := 2048;
my $SIG_ELEM_NOMINAL_GENERIC := 524288;
Parameter.HOW.add_method(Parameter, 'instantiate_generic', sub ($self, $type_environment) {
        # Clone with the type instantiated.
        my $ins      := pir::repr_clone__PP($self);
        my $type     := pir::getattribute__PPPs($self, Parameter, '$!nominal_type');
        my $ins_type := $type.HOW.instantiate_generic($type, $type_environment);
        unless $ins_type.HOW.archetypes.generic {
            my $flags := pir::repr_get_attr_int__IPPs($ins, Parameter, '$!flags');
            if $flags +& $SIG_ELEM_NOMINAL_GENERIC {
                pir::repr_bind_attr_int__0PPsI($ins, Parameter, '$!flags',
                    $flags - $SIG_ELEM_NOMINAL_GENERIC)
            }
        }
        pir::setattribute__0PPsP($ins, Parameter, '$!nominal_type', $ins_type)
    });
Parameter.HOW.add_method(Parameter, 'set_rw', sub ($self) {
        my $dcself := pir::perl6_decontainerize__PP($self);
        my $cd     := pir::getattribute__PPPs($dcself, Parameter, '$!container_descriptor');
        if $cd { $cd.set_rw(1) }
        pir::repr_bind_attr_int__0PPsI($dcself, Parameter, '$!flags',
            pir::repr_get_attr_int__IPPs($dcself, Parameter, '$!flags') + $SIG_ELEM_IS_RW);
    });
Parameter.HOW.add_method(Parameter, 'set_copy', sub ($self) {
        my $dcself := pir::perl6_decontainerize__PP($self);
        my $cd     := pir::getattribute__PPPs($dcself, Parameter, '$!container_descriptor');
        if $cd { $cd.set_rw(1) }
        pir::repr_bind_attr_int__0PPsI($dcself, Parameter, '$!flags',
            pir::repr_get_attr_int__IPPs($dcself, Parameter, '$!flags') + $SIG_ELEM_IS_COPY);
    });
Parameter.HOW.add_method(Parameter, 'set_required', sub ($self) {
        my $dcself := pir::perl6_decontainerize__PP($self);
        my $flags := pir::repr_get_attr_int__IPPs($dcself, Parameter, '$!flags');
        if $flags +& $SIG_ELEM_IS_OPTIONAL {
            pir::repr_bind_attr_int__0PPsI($dcself, Parameter, '$!flags',
                $flags - $SIG_ELEM_IS_OPTIONAL);
        }
    });
Parameter.HOW.add_method(Parameter, 'set_coercion', sub ($self, $type) {
        my $dcself := pir::perl6_decontainerize__PP($self);
        pir::repr_bind_attr_str__0PPsS($dcself, Parameter, '$!coerce_method', $type.HOW.name($type));
        pir::setattribute__0PPsP($dcself, Parameter, '$!coerce_type', $type);
    });
    
# class Code {
#     has $!do;                # Low level code object
#     has $!signature;         # Signature object
#     has $!dispatchees;       # If this is a dispatcher, the dispatchee list.
#     has $!dispatcher_cache;  # Stash for any extra dispatcher info.
#     ... # Uncomposed
# }
my stub Code metaclass Perl6::Metamodel::ClassHOW { ... };
Code.HOW.add_parent(Code, Any);
Code.HOW.add_attribute(Code, BOOTSTRAPATTR.new(:name<$!do>, :type(Mu)));
Code.HOW.add_attribute(Code, BOOTSTRAPATTR.new(:name<$!signature>, :type(Mu)));
Code.HOW.add_attribute(Code, BOOTSTRAPATTR.new(:name<$!dispatchees>, :type(Mu)));
Code.HOW.add_attribute(Code, BOOTSTRAPATTR.new(:name<$!dispatcher_cache>, :type(Mu)));
Code.HOW.add_attribute(Code, BOOTSTRAPATTR.new(:name<$!dispatcher>, :type(Mu)));

# Need multi-dispatch related methods and clone in here, plus
# generics instantiation.
Code.HOW.add_method(Code, 'is_dispatcher', sub ($self) {
        my $disp_list := pir::getattribute__PPPsP($self, Code, '$!dispatchees');
        pir::perl6_booleanize__PI(pir::defined__IP($disp_list));
    });
Code.HOW.add_method(Code, 'add_dispatchee', sub ($self, $dispatchee) {
        my $dc_self   := pir::perl6_decontainerize__PP($self);
        my $disp_list := pir::getattribute__PPPsP($dc_self, Code, '$!dispatchees');
        if pir::defined($disp_list) {
            $disp_list.push($dispatchee);
            pir::setattribute__0PPsP(pir::perl6_decontainerize__PP($dispatchee),
                Code, '$!dispatcher', $dc_self);
            pir::setattribute__0PPsP($dc_self, Code, '$!dispatcher_cache', pir::null__P());
        }
        else {
            pir::die("Cannot add a dispatchee to a non-dispatcher code object");
        }
    });
Code.HOW.add_method(Code, 'clone', sub ($self) {
        my $dcself := pir::perl6_decontainerize__PP($self);
        my $cloned := pir::repr_clone__PP($dcself);
        Q:PIR {
            $P0 = find_lex '$dcself'
            $P1 = find_lex 'Code'
            $P0 = getattribute $P0, $P1, '$!do'
            $P1 = getprop 'CLONE_CALLBACK', $P0
            if null $P1 goto no_callback
            $P2 = find_lex '$cloned'
            $P1($P0, $P2)
          no_callback:
        };
        pir::setattribute__0PPSP($cloned, Code, '$!do',
            pir::perl6_associate_sub_code_object__0PP(
                pir::clone__PP(pir::getattribute__PPPS($dcself, Code, '$!do')),
                $cloned))
    });
Code.HOW.add_method(Code, 'derive_dispatcher', sub ($self) {
        my $clone := $self.clone();
        pir::setattribute__0PPSP($clone, Code, '$!dispatchees',
            pir::clone__PP(pir::getattribute__PPPS($self, Code, '$!dispatchees')))
    });
Code.HOW.add_method(Code, 'is_generic', sub ($self) {
        # Delegate to signature, since it contains all the type info.
        pir::getattribute__PPPs($self, Code, '$!signature').is_generic()
    });
Code.HOW.add_method(Code, 'instantiate_generic', sub ($self, $type_environment) {
        # Clone the code object, then instantiate the generic signature. Also
        # need to clone dispatchees list.
        my $dcself := pir::perl6_decontainerize__PP($self);
        my $ins := $self.clone();
        if pir::defined(nqp::getattr($dcself, Code, '$!dispatchees')) {
            nqp::bindattr($ins, Code, '$!dispatchees',
                pir::clone__PP(nqp::getattr($dcself, Code, '$!dispatchees')));
        }
        my $sig := pir::getattribute__PPPs($dcself, Code, '$!signature');
        pir::setattribute__0PPsP($ins, Code, '$!signature',
            $sig.instantiate_generic($type_environment))
    });
Code.HOW.add_method(Code, 'name', sub ($self) {
        ~pir::getattribute__PPPs(pir::perl6_decontainerize__PP($self),
            Code, '$!do')
    });
Code.HOW.add_method(Code, 'set_name', sub ($self, $name) {
        pir::assign__vPS(
            pir::getattribute__PPPs(pir::perl6_decontainerize__PP($self), Code, '$!do'),
            $name)
    });
Code.HOW.add_method(Code, 'dispatcher', sub ($self) {
        pir::getattribute__PPPs(pir::perl6_decontainerize__PP($self),
            Code, '$!dispatcher')
    });
Code.HOW.add_method(Code, 'id', sub ($self) {
        nqp::where(pir::getattribute__PPPs(pir::perl6_decontainerize__PP($self),
            Code, '$!do'))
    });
pir::perl6_set_type_code__vP(Code);
    
# Need to actually run the code block. Also need this available before we finish
# up the stub.
Code.HOW.add_parrot_vtable_mapping(Code, 'invoke', nqp::null());
Code.HOW.add_parrot_vtable_handler_mapping(Code, 'invoke', '$!do');
Code.HOW.publish_parrot_vtable_handler_mapping(Code);
Code.HOW.publish_parrot_vtable_mapping(Code);

# class Block is Code { ... }
my stub Block metaclass Perl6::Metamodel::ClassHOW { ... };
Block.HOW.add_parent(Block, Code);
Block.HOW.add_attribute(Block, BOOTSTRAPATTR.new(:name<$!state_vars>, :type(Mu)));
Block.HOW.publish_parrot_vtable_handler_mapping(Block);
Block.HOW.publish_parrot_vtable_mapping(Block);
Block.HOW.add_method(Block, 'clone', sub ($self) {
        my $dcself := pir::perl6_decontainerize__PP($self);
        my $cloned := pir::repr_clone__PP($dcself);
        Q:PIR {
            $P0 = find_lex '$dcself'
            $P1 = find_lex 'Code'
            $P0 = getattribute $P0, $P1, '$!do'
            $P1 = getprop 'CLONE_CALLBACK', $P0
            if null $P1 goto no_callback
            $P2 = find_lex '$cloned'
            $P1($P0, $P2)
          no_callback:
        };
        pir::setattribute__0PPSP($cloned, Block, '$!state_vars', nqp::null());
        pir::setattribute__0PPSP($cloned, Code, '$!do',
            pir::perl6_associate_sub_code_object__0PP(
                pir::clone__PP(pir::getattribute__PPPS($dcself, Code, '$!do')),
                $cloned))
    });

# class Routine is Block { ... }
my stub Routine metaclass Perl6::Metamodel::ClassHOW { ... };
Routine.HOW.add_parent(Routine, Block);
Routine.HOW.add_attribute(Routine, BOOTSTRAPATTR.new(:name<$!rw>, :type(int)));
Routine.HOW.publish_parrot_vtable_handler_mapping(Routine);
Routine.HOW.publish_parrot_vtable_mapping(Routine);
Routine.HOW.add_method(Routine, 'set_rw', sub ($self) {
        my $dcself := pir::perl6_decontainerize__PP($self);
        pir::repr_bind_attr_int__0PPsi($dcself, Routine, '$!rw', 1);
    });

# class Sub is Routine { ... }
my stub Sub metaclass Perl6::Metamodel::ClassHOW { ... };
Sub.HOW.add_parent(Sub, Routine);
Sub.HOW.publish_parrot_vtable_handler_mapping(Sub);
Sub.HOW.publish_parrot_vtable_mapping(Sub);

# class Method is Routine { ... }
my stub Method metaclass Perl6::Metamodel::ClassHOW { ... };
Method.HOW.add_parent(Method, Routine);
Method.HOW.publish_parrot_vtable_handler_mapping(Method);
Method.HOW.publish_parrot_vtable_mapping(Method);

# class Submethod is Routine { ... }
my stub Submethod metaclass Perl6::Metamodel::ClassHOW { ... };
Submethod.HOW.add_parent(Submethod, Routine);
Submethod.HOW.publish_parrot_vtable_handler_mapping(Submethod);
Submethod.HOW.publish_parrot_vtable_mapping(Submethod);

# class Regex is Method { ... }
my stub Regex metaclass Perl6::Metamodel::ClassHOW { ... };
Regex.HOW.add_parent(Regex, Method);
Regex.HOW.publish_parrot_vtable_handler_mapping(Regex);
Regex.HOW.publish_parrot_vtable_mapping(Regex);

# class Str is Cool {
#     has str $!value is box_target;
#     ...
# }
my stub Str metaclass Perl6::Metamodel::ClassHOW { ... };
Str.HOW.add_parent(Str, Cool);
Str.HOW.add_attribute(Str, BOOTSTRAPATTR.new(:name<$!value>, :type(str), :box_target(1)));
Str.HOW.set_boolification_mode(Str, 4);
Str.HOW.publish_boolification_spec(Str);

# XXX: Numeric and Real are really roles; this stubs them in as classes for now.
# class Numeric is Cool { ... }
my stub Numeric metaclass Perl6::Metamodel::ClassHOW { ... };
Numeric.HOW.add_parent(Numeric, Cool);

# class Real is Numeric { ... }
my stub Real metaclass Perl6::Metamodel::ClassHOW { ... };
Real.HOW.add_parent(Real, Numeric);

# class Int is (Cool does) Real {
#     has int $!value is box_target;
#     ...
# }
my stub Int metaclass Perl6::Metamodel::ClassHOW { ... };
Int.HOW.add_parent(Int, Real);
Int.HOW.add_attribute(Int, BOOTSTRAPATTR.new(:name<$!value>, :type(int), :box_target(1)));
Int.HOW.set_boolification_mode(Int, 1);
Int.HOW.publish_boolification_spec(Int);

# class Num is (Cool does) Real {
#     has num $!value is box_target;
#     ...
# }
my stub Num metaclass Perl6::Metamodel::ClassHOW { ... };
Num.HOW.add_parent(Num, Real);
Num.HOW.add_attribute(Num, BOOTSTRAPATTR.new(:name<$!value>, :type(num), :box_target(1)));
Num.HOW.set_boolification_mode(Num, 2);
Num.HOW.publish_boolification_spec(Num);

# Stash these common types for box ops.
pir::perl6_set_types_ins__vPPP(Int, Num, Str);

# class Parcel is Cool {
#     ...
# }
my stub Parcel metaclass Perl6::Metamodel::ClassHOW { ... };
Parcel.HOW.add_parent(Parcel, Cool);
Parcel.HOW.add_attribute(Parcel, scalar_attr('$!storage', Mu));

# class Iterable is Cool {
#     ...
# }
my stub Iterable metaclass Perl6::Metamodel::ClassHOW { ... };
Iterable.HOW.add_parent(Iterable, Cool);

# class Iterator is Iterable {
#     ...
# }
my stub Iterator metaclass Perl6::Metamodel::ClassHOW { ... };
Iterator.HOW.add_parent(Iterator, Iterable);


# class ListIter is Iterator {
#     has $!reified;
#     has $!nextiter;
#     has $!rest;
#     has $!list;
#    ...
# }
my stub ListIter metaclass Perl6::Metamodel::ClassHOW { ... };
ListIter.HOW.add_parent(ListIter, Iterator);
ListIter.HOW.add_attribute(ListIter, scalar_attr('$!reified', Mu));
ListIter.HOW.add_attribute(ListIter, scalar_attr('$!nextiter', Mu));
ListIter.HOW.add_attribute(ListIter, scalar_attr('$!rest', Mu));
ListIter.HOW.add_attribute(ListIter, scalar_attr('$!list', Mu));

# class List is Iterable {
#     has $!items;
#     has $!flattens;
#     has $!nextiter;
#     ...
# }
my stub List metaclass Perl6::Metamodel::ClassHOW { ... };
List.HOW.add_parent(List, Iterable);
List.HOW.add_attribute(List, scalar_attr('$!items', Mu));
List.HOW.add_attribute(List, scalar_attr('$!flattens', Mu));
List.HOW.add_attribute(List, scalar_attr('$!nextiter', Mu));

# class Array is List {
#     has $!descriptor;
#     ...
# }
my stub Array metaclass Perl6::Metamodel::ClassHOW { ... };
Array.HOW.add_parent(Array, List);
Array.HOW.add_attribute(Array, BOOTSTRAPATTR.new(:name<$!descriptor>, :type(Mu)));

# class LoL is List {
#     has $!descriptor;
#     ...
# }
my stub LoL metaclass Perl6::Metamodel::ClassHOW { ... };
LoL.HOW.add_parent(LoL, List);
LoL.HOW.add_attribute(LoL, BOOTSTRAPATTR.new(:name<$!descriptor>, :type(Mu)));

# my class EnumMap is Iterable {
#     has $!storage;
#     ...
# }
my stub EnumMap metaclass Perl6::Metamodel::ClassHOW { ... };
EnumMap.HOW.add_parent(EnumMap, Iterable);
EnumMap.HOW.add_attribute(EnumMap, scalar_attr('$!storage', Mu));

# my class Hash is EnumMap {
#     has $!descriptor;
#     ...
# }
my stub Hash metaclass Perl6::Metamodel::ClassHOW { ... };
Hash.HOW.add_parent(Hash, EnumMap);
Hash.HOW.add_attribute(Hash, BOOTSTRAPATTR.new(:name<$!descriptor>, :type(Mu)));

# class Capture {
#     ...
# }
my stub Capture metaclass Perl6::Metamodel::ClassHOW { ... };
Capture.HOW.add_parent(Capture, Any);

# Configure declarative listy/hashy types.
pir::perl6_set_types_list_array_lol__vPP(List, ListIter, Array, LoL, Parcel);
pir::perl6_set_types_enummap_hash__vPP(EnumMap, Hash);
pir::perl6_set_type_capture__vP(Capture);

# XXX Quick and dirty Bool. Probably done by EnumHOW in the end.
my stub Bool metaclass Perl6::Metamodel::ClassHOW { ... };
Bool.HOW.add_parent(Bool, Cool);
Bool.HOW.add_attribute(Bool, BOOTSTRAPATTR.new(:name<$!value>, :type(int), :box_target(1)));
Bool.HOW.set_boolification_mode(Bool, 1);
Bool.HOW.publish_boolification_spec(Bool);

# Set up Stash type, using a Parrot hash under the hood for storage.
my stub Stash metaclass Perl6::Metamodel::ClassHOW { ... };
Stash.HOW.add_parent(Stash, Hash);
Stash.HOW.add_parrot_vtable_handler_mapping(EnumMap, 'get_pmc_keyed', '$!storage');
Stash.HOW.add_parrot_vtable_handler_mapping(EnumMap, 'get_pmc_keyed_str', '$!storage');
Stash.HOW.add_parrot_vtable_handler_mapping(EnumMap, 'set_pmc_keyed', '$!storage');
Stash.HOW.add_parrot_vtable_handler_mapping(EnumMap, 'set_pmc_keyed_str', '$!storage');
Stash.HOW.add_parrot_vtable_handler_mapping(EnumMap, 'exists_keyed', '$!storage');
Stash.HOW.add_parrot_vtable_handler_mapping(EnumMap, 'exists_keyed_str', '$!storage');
Stash.HOW.add_parrot_vtable_handler_mapping(EnumMap, 'get_iter', '$!storage');
Stash.HOW.publish_parrot_vtable_handler_mapping(Stash);

# Set this Stash type for the various types of package.
Perl6::Metamodel::PackageHOW.set_stash_type(Stash, EnumMap);
Perl6::Metamodel::ModuleHOW.set_stash_type(Stash, EnumMap);
Perl6::Metamodel::NativeHOW.set_stash_type(Stash, EnumMap);
Perl6::Metamodel::ClassHOW.set_stash_type(Stash, EnumMap);
Perl6::Metamodel::GrammarHOW.set_stash_type(Stash, EnumMap);
Perl6::Metamodel::ParametricRoleHOW.set_stash_type(Stash, EnumMap);
Perl6::Metamodel::ParametricRoleGroupHOW.set_stash_type(Stash, EnumMap);

# Give everything we've set up so far a Stash.
Perl6::Metamodel::ClassHOW.add_stash(Mu);
Perl6::Metamodel::ClassHOW.add_stash(Any);
Perl6::Metamodel::ClassHOW.add_stash(Cool);
Perl6::Metamodel::ClassHOW.add_stash(Attribute);
Perl6::Metamodel::ClassHOW.add_stash(Signature);
Perl6::Metamodel::ClassHOW.add_stash(Parameter);
Perl6::Metamodel::ClassHOW.add_stash(Code);
Perl6::Metamodel::ClassHOW.add_stash(Block);
Perl6::Metamodel::ClassHOW.add_stash(Routine);
Perl6::Metamodel::ClassHOW.add_stash(Sub);
Perl6::Metamodel::ClassHOW.add_stash(Method);
Perl6::Metamodel::ClassHOW.add_stash(Str);
Perl6::Metamodel::ClassHOW.add_stash(Int);
Perl6::Metamodel::ClassHOW.add_stash(Num);
Perl6::Metamodel::ClassHOW.add_stash(Scalar);
Perl6::Metamodel::ClassHOW.add_stash(Bool);
Perl6::Metamodel::ClassHOW.add_stash(Stash);
Perl6::Metamodel::ClassHOW.add_stash(List);
Perl6::Metamodel::ClassHOW.add_stash(Array);
Perl6::Metamodel::ClassHOW.add_stash(Hash);

# Make Parrot invoke v-table construct a capture and delegate off
# to postcircumfix:<( )>.
Mu.HOW.add_parrot_vtable_mapping(Mu, 'invoke',
    sub ($self, *@pos, *%named) {
        my $c := nqp::create(Capture);
        nqp::bindattr($c, Capture, '$!list', @pos);
        nqp::bindattr($c, Capture, '$!hash', %named);
        $self.postcircumfix:<( )>($c);
    });
Mu.HOW.publish_parrot_vtable_mapping(Mu);

# If we don't already have a PROCESS, set it up.
my $PROCESS;
my $hll_ns := pir::get_root_global__PS('perl6');
if pir::exists($hll_ns, 'PROCESS') {
    $PROCESS := $hll_ns<PROCESS>;
}
else {
    my stub PROCESS metaclass Perl6::Metamodel::ModuleHOW { ... };
    PROCESS.HOW.compose(PROCESS);
    Perl6::Metamodel::ModuleHOW.add_stash(PROCESS);
    $hll_ns<PROCESS> := $PROCESS := PROCESS;
}

# Bool::False and Bool::True.
# XXX $*ST calls here are deeply evil.
# XXX Maybe Bool is an enum, so we do it with EnumHOW?
my $false := pir::repr_instance_of__PP(Bool);
pir::repr_bind_attr_int__vPPsI($false, Bool, '$!value', 0);
$*ST.add_object($false);
(Bool.WHO)<False> := $false;
my $true := pir::repr_instance_of__PP(Bool);
pir::repr_bind_attr_int__vPPsI($true, Bool, '$!value', 1);
$*ST.add_object($true);
(Bool.WHO)<True> := $true;
pir::perl6_set_bools__vPP($false, $true);

# Roles pretend to be narrower than certain types for the purpose
# of type checking. Also, they pun to classes.
Perl6::Metamodel::ParametricRoleGroupHOW.pretend_to_be([Cool, Any, Mu]);
Perl6::Metamodel::ParametricRoleGroupHOW.configure_punning(
    Perl6::Metamodel::ClassHOW,
    hash( ACCEPTS => Mu ));
Perl6::Metamodel::ParametricRoleHOW.pretend_to_be([Cool, Any, Mu]);
Perl6::Metamodel::ParametricRoleHOW.configure_punning(
    Perl6::Metamodel::ClassHOW,
    hash( ACCEPTS => Mu ));
Perl6::Metamodel::CurriedRoleHOW.pretend_to_be([Cool, Any, Mu]);
Perl6::Metamodel::CurriedRoleHOW.configure_punning(
    Perl6::Metamodel::ClassHOW,
    hash( ACCEPTS => Mu ));

# Need to tell parametric role groups how to create a dispatcher.
Perl6::Metamodel::ParametricRoleGroupHOW.set_selector_creator({
    my $sel := nqp::create(Sub);
    my $onlystar := -> *@pos, *%named {
        pir::perl6_enter_multi_dispatch_from_onlystar_block__P();
    };
    pir::perl6_associate_sub_code_object__vPP($onlystar, $sel);
    nqp::bindattr($sel, Code, '$!do', $onlystar);
    nqp::bindattr($sel, Code, '$!dispatchees', []);
    $sel
});
    
# Similar for packages and modules, but just has methods from Any.
Perl6::Metamodel::PackageHOW.pretend_to_be([Any, Mu]);
Perl6::Metamodel::PackageHOW.delegate_methods_to(Any);
Perl6::Metamodel::ModuleHOW.pretend_to_be([Any, Mu]);
Perl6::Metamodel::ModuleHOW.delegate_methods_to(Any);

# We'll build container descriptors for $_, $! and $/ that we can
# share with all of the magically/lazily created scalars.
my $topic_cd := Perl6::Metamodel::ContainerDescriptor.new(
    :of(Mu), :rw(1), :name('$_'));
my $error_cd := Perl6::Metamodel::ContainerDescriptor.new(
    :of(Mu), :rw(1), :name('$!'));
my $match_cd := Perl6::Metamodel::ContainerDescriptor.new(
    :of(Mu), :rw(1), :name('$/'));
pir::new__PsP('Perl6LexPad', hash()).configure_magicals(
    $topic_cd, $error_cd, $match_cd, Scalar, Any, EnumMap, Hash, Block);

# Setup some regexy/grammary bits.
use QRegex;
my stub Grammar metaclass Perl6::Metamodel::ClassHOW { ... };
Perl6::Metamodel::GrammarHOW.set_default_parent_type(Grammar);
Perl6::Metamodel::ClassHOW.add_stash(Grammar);

# Export the metamodel bits to a Metamodel namespace so it's available
# from user land.
my stub Metamodel metaclass Perl6::Metamodel::PackageHOW { ... };
Perl6::Metamodel::PackageHOW.add_stash(Metamodel);
for Perl6::Metamodel.WHO {
    (Metamodel.WHO){$_.key} := $_.value;
}


# Build up EXPORT::DEFAULT.
my module EXPORT {
    our module DEFAULT {
        $?PACKAGE.WHO<Mu>        := Mu;
        $?PACKAGE.WHO<Any>       := Any;
        $?PACKAGE.WHO<Cool>      := Cool;
        $?PACKAGE.WHO<Attribute> := Attribute;
        $?PACKAGE.WHO<Signature> := Signature;
        $?PACKAGE.WHO<Parameter> := Parameter;
        $?PACKAGE.WHO<Code>      := Code;
        $?PACKAGE.WHO<Block>     := Block;
        $?PACKAGE.WHO<Routine>   := Routine;
        $?PACKAGE.WHO<Sub>       := Sub;
        $?PACKAGE.WHO<Method>    := Method;
        $?PACKAGE.WHO<Submethod> := Submethod;
        $?PACKAGE.WHO<Regex>     := Regex;
        $?PACKAGE.WHO<Str>       := Str;
        $?PACKAGE.WHO<Numeric>   := Numeric;
        $?PACKAGE.WHO<Real>      := Real;
        $?PACKAGE.WHO<Int>       := Int;
        $?PACKAGE.WHO<Num>       := Num;
        $?PACKAGE.WHO<Parcel>    := Parcel;  
        $?PACKAGE.WHO<Iterable>  := Iterable;
        $?PACKAGE.WHO<Iterator>  := Iterator;
        $?PACKAGE.WHO<ListIter>  := ListIter;
        $?PACKAGE.WHO<List>      := List;
        $?PACKAGE.WHO<Array>     := Array;
        $?PACKAGE.WHO<LoL>       := LoL;
        $?PACKAGE.WHO<EnumMap>   := EnumMap;
        $?PACKAGE.WHO<Hash>      := Hash;
        $?PACKAGE.WHO<Capture>   := Capture;
        $?PACKAGE.WHO<Stash>     := Stash;
        $?PACKAGE.WHO<Scalar>    := Scalar;
        $?PACKAGE.WHO<Grammar>   := Grammar;
        $?PACKAGE.WHO<PROCESS>   := $PROCESS;
        $?PACKAGE.WHO<Bool>      := Bool;
        $?PACKAGE.WHO<False>     := $false;
        $?PACKAGE.WHO<True>      := $true;
        $?PACKAGE.WHO<ContainerDescriptor> := Perl6::Metamodel::ContainerDescriptor;
        $?PACKAGE.WHO<MethodDispatcher>    := Perl6::Metamodel::MethodDispatcher;
        $?PACKAGE.WHO<MultiDispatcher>     := Perl6::Metamodel::MultiDispatcher;
        $?PACKAGE.WHO<WrapDispatcher>      := Perl6::Metamodel::WrapDispatcher;
        $?PACKAGE.WHO<StaticLexPad>        := Perl6::Metamodel::StaticLexPad;
        $?PACKAGE.WHO<NQPCursorRole>       := NQPCursorRole;
        $?PACKAGE.WHO<Metamodel>           := Metamodel;
    }
}
