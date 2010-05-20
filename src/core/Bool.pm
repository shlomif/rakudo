augment class Bool {
    method Bool { self }
    method ACCEPTS($topic) { self }

    method perl() { self ?? "Bool::True" !! "Bool::False"; }

    method Bridge() { self ?? 1.Bridge !! 0.Bridge }
}

enum Order (Increase => 3, Same => 0, Decrease => 1);
