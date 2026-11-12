package core

import "fmt"

func checkMountBaseDependencies(base *mountBase, mounted []string, edges map[string][]string) error {
	known := map[string]bool{}
	for _, name := range reservedProxyNames {
		known[name] = true
	}
	for name := range base.proxyTypes {
		known[name] = true
		edges[name] = append(edges[name], base.proxyDialers[name]...)
	}
	for _, pd := range base.providers {
		for _, name := range pd.names {
			known[name] = true
		}
	}
	for _, name := range mounted {
		known[name] = true
	}
	for _, group := range base.groups {
		known[groupString(group, "name")] = true
	}
	return checkMountDependencies(edges, mounted, func(name string) bool { return known[name] })
}

// Only dependencies reachable from newly introduced nodes belong to mount validation.
func checkMountDependencies(edges map[string][]string, roots []string, known func(string) bool) error {
	state := map[string]uint8{}
	var visit func(string) error
	visit = func(name string) error {
		if !known(name) {
			return fmt.Errorf("mounted node dependency %q is missing", name)
		}
		switch state[name] {
		case 1:
			return fmt.Errorf("mounted node dependency cycle at %q", name)
		case 2:
			return nil
		}
		state[name] = 1
		for _, next := range edges[name] {
			if err := visit(next); err != nil {
				return fmt.Errorf("%s: %w", name, err)
			}
		}
		state[name] = 2
		return nil
	}
	for _, name := range roots {
		if err := visit(name); err != nil {
			return err
		}
	}
	return nil
}
