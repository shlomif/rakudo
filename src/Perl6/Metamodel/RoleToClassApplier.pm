my class RoleToClassApplier {
    sub has_method($target, $name, $local) {
        my %mt := $target.HOW.method_table($target);
        return pir::exists(%mt, $name)
    }
    
    sub has_private_method($target, $name) {
        my %pmt := $target.HOW.private_method_table($target);
        return pir::exists(%pmt, $name)
    }

    sub has_attribute($target, $name) {
        my @attributes := $target.HOW.attributes($target, :local(1));
        for @attributes {
            if $_.name eq $name { return 1; }
        }
        return 0;
    }

    method apply($target, @roles) {
        # If we have many things to compose, then get them into a single helper
        # role first.
        my $to_compose;
        my $to_compose_meta;
        if +@roles == 1 {
            $to_compose := @roles[0];
            $to_compose_meta := $to_compose.HOW;
        }
        else {
            $to_compose := $concrete.new_type();
            $to_compose_meta := $to_compose.HOW;
            for @roles {
                $to_compose_meta.add_role($to_compose, $_);
            }
            $to_compose := $to_compose_meta.compose($to_compose);
        }

        # Collisions?
        my @collisions := $to_compose_meta.collisions($to_compose);
        for @collisions {
            unless has_method($target, $_.name, 1) {
                pir::die("Method '" ~ $_.name ~
                    "' must be resolved by class " ~
                    $target.HOW.name($target) ~
                    " because it exists in multiple roles (" ~
                    pir::join(", ", $_.roles) ~ ")");
            }
        }

        # Compose in any methods.
        my @methods := $to_compose_meta.methods($to_compose, :local(1));
        for @methods {
            my $name;
            try { $name := $_.name }
            unless $name { $name := ~$_ }
            unless has_method($target, $name, 0) {
                $target.HOW.add_method($target, $name, $_);
            }
        }
        if pir::can__IPs($to_compose_meta, 'private_method_table') {
            for $to_compose_meta.private_method_table($to_compose) {
                unless has_private_method($target, $_.key) {
                    $target.HOW.add_private_method($target, $_.key, $_.value);
                }
            }
        }
        
        # Compose in any multi-methods; conflicts can be caught by
        # the multi-dispatcher later.
        if pir::can__IPs($to_compose_meta, 'multi_methods_to_incorporate') {
            my @multis := $to_compose_meta.multi_methods_to_incorporate($to_compose);
            for @multis {
                $target.HOW.add_multi_method($target, $_.name, $_.code);
            }
        }

        # Compose in any role attributes.
        my @attributes := $to_compose_meta.attributes($to_compose, :local(1));
        for @attributes {
            if has_attribute($target, $_.name) {
                pir::die("Attribute '" ~ $_.name ~ "' already exists in the class '" ~
                    $target.HOW.name($target) ~ "', but a role also wishes to compose it");
            }
            $target.HOW.add_attribute($target, $_);
        }
        
        # Compose in any parents.
        if pir::can($to_compose_meta, 'parents') {
            my @parents := $to_compose_meta.parents($to_compose, :local(1));
            for @parents {
                $target.HOW.add_parent($target, $_);
            }
        }
        
        1;
    }
}
