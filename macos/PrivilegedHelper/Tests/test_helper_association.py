import copy
import plistlib
import re
import unittest
from pathlib import Path

MACOS = Path(__file__).resolve().parents[2]
TRUST = (MACOS / 'Shared/HelperTrust.m').read_text()
MAINTENANCE = (MACOS / 'PrivilegedHelper/Maintenance.m').read_text()


def function(source, declaration):
    start = source.index(declaration)
    opening = source.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


def source_canonical():
    constants = dict(re.findall(r'NSString \* const (\w+) = @"([^"]+)";', TRUST))
    executable = function(TRUST, 'NSString *FCInstalledExecutable(')
    suffix = re.search(r'FCHelperLabel\]\) return \[FCInstalledBundle stringByAppendingPathComponent:@"([^"]+)"', executable)[1]
    constants['HELPER_PATH'] = constants['FCInstalledBundle'] + '/' + suffix
    body = function(TRUST, 'NSDictionary *FCCanonicalHelperPlist(void)')
    literal = body.split('return ', 1)[1].rsplit(';', 1)[0]
    literal = literal.replace('FCInstalledExecutable(FCHelperLabel)', 'HELPER_PATH')
    tokens = iter(re.findall(r'@"[^"]*"|@\{|@\[|@YES|\w+|[}:,\]]', literal))

    def parse(token):
        if token in ('@{', '@['):
            closing = '}' if token == '@{' else ']'
            result = {} if token == '@{' else []
            token = next(tokens)
            while token != closing:
                key = parse(token)
                if isinstance(result, dict):
                    assert next(tokens) == ':'
                    result[key] = parse(next(tokens))
                else:
                    result.append(key)
                token = next(tokens)
                if token == ',':
                    token = next(tokens)
            return result
        if token.startswith('@"'):
            return token[2:-1]
        return True if token == '@YES' else constants[token]

    return parse(next(tokens))


NEW = source_canonical()
OLD = {k: v for k, v in NEW.items() if k != 'AssociatedBundleIdentifiers'}


def classify(value):
    if type(value) is not dict:
        return 'invalid'
    if any(type(value.get(k)) is not str for k in ('Label', 'Program', 'ProcessType')):
        return 'invalid'
    services = value.get('MachServices')
    if type(services) is not dict or len(services) != 1 or type(services.get(NEW['Label'])) is not bool:
        return 'invalid'
    association = value.get('AssociatedBundleIdentifiers')
    if 'AssociatedBundleIdentifiers' in value and (type(association) is not list or len(association) != 1 or type(association[0]) is not str):
        return 'invalid'
    return 'new' if value == NEW else 'old' if value == OLD else 'invalid'


def trusted(value, protected=True, maintenance=False):
    return protected and classify(value) in (('old', 'new') if maintenance else ('new',))


class HelperAssociationTests(unittest.TestCase):
    def test_canonical_writer_matches_source_plist(self):
        with (MACOS / 'PrivilegedHelper/com.layoute.flash.helper.plist').open('rb') as source:
            self.assertEqual(NEW, plistlib.load(source))
        self.assertEqual(NEW['AssociatedBundleIdentifiers'], ['com.layoute.flash'])
        commit = function(MAINTENANCE, 'static BOOL FCCommit(void)')
        self.assertIn('FCWriteCanonicalHelperPlist()', commit)
        writer = function(MAINTENANCE, 'static BOOL FCWriteCanonicalHelperPlist(void)')
        self.assertIn('NSDictionary *plist = FCCanonicalHelperPlist();', writer)
        self.assertIn('FCLegacyPlistTrusted()', writer)
        self.assertNotIn('@"MachServices"', commit)

    def test_exact_old_new_and_protected_tree(self):
        for value, runtime in ((OLD, False), (NEW, True)):
            self.assertEqual(trusted(value), runtime)
            self.assertTrue(trusted(value, maintenance=True))
            self.assertFalse(trusted(value, protected=False))
            self.assertFalse(trusted(value, protected=False, maintenance=True))
        for name in ('BOOL FCLegacyPlistTrusted(void)', 'BOOL FCLegacyPlistTrustedForMaintenance(void)'):
            body = function(TRUST, name)
            self.assertIn('if (!FCProtectedTree(FCLegacyPlist, NO)) return NO;', body)
        classifier = function(TRUST, 'FCHelperPlistSchema FCClassifyHelperPlist(')
        for guard in ('NSDictionary.class', 'NSString.class', 'NSArray.class', 'CFBooleanGetTypeID()',
                      'isEqualToDictionary:canonical', 'isEqualToDictionary:legacy'):
            self.assertIn(guard, classifier)
        self.assertNotIn('removeObjectForKey', classifier.split('NSDictionary *canonical')[0])

    def test_invalid_fixtures(self):
        fixtures = [None, [], {}, {**NEW, 'Unknown': True}]
        for key in NEW:
            value = copy.deepcopy(NEW)
            del value[key]
            if key != 'AssociatedBundleIdentifiers':
                fixtures.append(value)
        for value in ([], ['com.layoute.flash.service'], ['com.layoute.flash', 'other'],
                      'com.layoute.flash', True, [1], {}, None):
            fixtures.append({**NEW, 'AssociatedBundleIdentifiers': value})
        for key, values in {'Label': ['wrong', 1], 'Program': ['/tmp/FlashHelper', 1],
                            'ProcessType': ['Background', 1],
                            'MachServices': [{NEW['Label']: 1}, {NEW['Label']: False},
                                             {'wrong': True}, {}, [], {NEW['Label']: True, 'extra': True}]}.items():
            fixtures.extend({**NEW, key: value} for value in values)
        for value in fixtures:
            with self.subTest(value=value):
                self.assertFalse(trusted(value))
                self.assertFalse(trusted(value, maintenance=True))

    def test_compatibility_only_maintenance(self):
        for path in MACOS.rglob('*'):
            if path.suffix not in ('.m', '.h') or 'Tests' in path.parts:
                continue
            if path.name not in ('HelperTrust.h', 'HelperTrust.m', 'Maintenance.m'):
                self.assertNotIn('FCLegacyPlistTrustedForMaintenance', path.read_text())
        for path in ('PrivilegedHelper/Supervisor.m', 'Runner/ManagedHelperBridge.m'):
            self.assertIn('FCLegacyPlistTrusted()', (MACOS / path).read_text())
        for name in ('FCPrepare', 'FCBeginRemoval', 'FCBegin', 'FCStageReady', 'FCRemovalState', 'FCFinishRemoval'):
            self.assertIn('FCLegacyPlistTrustedForMaintenance()', function(MAINTENANCE, 'static ' + ('int ' if name == 'FCBeginRemoval' else 'FCRemovalAction ' if name == 'FCRemovalState' else 'BOOL ') + name + '('))
        self.assertIn('FCResult(FCLegacyPlistTrustedForMaintenance(), "launch-daemon-untrusted")', MAINTENANCE)
        self.assertIn('FCLegacyPlistTrusted(), "installed-state-untrusted")', MAINTENANCE)

    def test_commit_input_before_swap_output_before_journal(self):
        body = function(MAINTENANCE, 'static BOOL FCCommit(void)')
        guard = 'if (first ? !FCAbsent(FCLegacyPlist) : !FCLegacyPlistTrustedForMaintenance()) return NO;'
        self.assertLess(body.index(guard), body.index('rename('))
        self.assertLess(body.index('FCTransactionCommitAllowed'), body.index(guard))
        self.assertIn('BOOL first = [state[@"old"] isEqual:@"absent"];', body)
        self.assertLess(body.index('FCWriteCanonicalHelperPlist()'), body.index('FCLegacyPlistTrusted()'))
        self.assertLess(body.index('FCLegacyPlistTrusted()'), body.index('FCWriteTransaction(@"committed"'))
        self.assertIn('[FCSeal(FCInstalledBundle) isEqual:state[@"new"]]', body)
        finish = function(MAINTENANCE, 'static BOOL FCFinish(void)')
        self.assertIn('!FCLegacyPlistTrusted()', finish)
        self.assertNotIn('ForMaintenance', finish)

    def test_transition_and_interruption_fixtures(self):
        for installed, plist in (('absent', None), ('old', OLD), ('old', NEW)):
            first = installed == 'absent'
            self.assertTrue(plist is None if first else trusted(plist, maintenance=True))
            self.assertTrue(trusted(NEW))
        for plist in (OLD, NEW):
            self.assertTrue(trusted(plist, maintenance=True))  # removal and repair input
            self.assertFalse(trusted(plist, protected=False, maintenance=True))
        for current, plist in (('old', OLD), ('new', OLD), ('new', NEW)):
            self.assertTrue(trusted(plist, maintenance=True))
            can_commit_original = current == 'old'
            self.assertEqual(can_commit_original, current != 'new')
        begin = function(MAINTENANCE, 'static BOOL FCBegin(')
        self.assertIn('FCTransactionResumeAllowed', begin)
        self.assertIn('FCAbsent(FCLegacyPlist) && ![current isEqual:@"absent"]) {', begin)
        self.assertLess(begin.index('FCTransactionResumeAllowed'), begin.index('FCWriteTransaction(@"staging"'))
        stage = function(MAINTENANCE, 'static BOOL FCStageReady(void)')
        self.assertIn('[state[@"old"] isEqual:@"absent"] ? FCAbsent(FCLegacyPlist) : FCLegacyPlistTrustedForMaintenance()', stage)


    def test_first_install_postrename_repair_complete_model(self):
        recovery = function(MAINTENANCE, 'static BOOL FCFirstInstallPlistRecoveryAllowed(')
        expression = recovery.split('return ', 1)[1].rsplit(';', 1)[0]
        substitutions = {
            '[state[@"phase"] isEqual:@"prepared"]': '(state.get("phase") == "prepared")',
            '[state[@"old"] isEqual:@"absent"]': '(state.get("old") == "absent")',
            '[current isEqual:state[@"new"]]': '(current == state.get("new"))',
            'current.length': 'len(current)',
            'FCAbsent(FCLegacyPlist)': 'plist_absent',
            'FCAbsent(FCIncomingBundle())': 'incoming_absent',
            'FCQuiescent()': 'quiescent',
            '&&': ' and ',
        }
        for old, new in substitutions.items():
            expression = expression.replace(old, new)
        expression = ' '.join(expression.split())

        def permits(state, current, plist_absent=True, incoming_absent=True, quiescent=True):
            return bool(eval(expression, {'__builtins__': {}, 'len': len}, locals()))

        seal = 'a' * 128
        state = {'phase': 'prepared', 'old': 'absent', 'new': seal}
        self.assertTrue(permits(state, seal))
        for changed in ({'old': 'b' * 128}, {'phase': 'staging'}, {'phase': 'committed'},
                        {'new': 'b' * 128}):
            self.assertFalse(permits({**state, **changed}, seal))
        self.assertFalse(permits(None, seal))
        self.assertFalse(permits(state, 'absent'))
        for keyword in ('plist_absent', 'incoming_absent', 'quiescent'):
            self.assertFalse(permits(state, seal, **{keyword: False}))

        # Synthetic model, not native crash-recovery execution.
        plist, journal, current = None, state.copy(), seal
        before = journal.copy()
        self.assertFalse(current == journal['old'])  # original commit cannot replay rename
        self.assertTrue(permits(journal, current))
        plist = copy.deepcopy(NEW)  # guarded canonical completion before restaging
        self.assertEqual(journal, before)  # original evidence survives plist-write interruption
        self.assertTrue(trusted(plist))
        journal = {'phase': 'staging', 'old': current, 'new': ''}
        incoming = 'b' * 128
        self.assertTrue(trusted(plist, maintenance=True))  # stageReady
        journal = {'phase': 'prepared', 'old': current, 'new': incoming}
        self.assertEqual(current, journal['old'])
        self.assertTrue(trusted(plist, maintenance=True))  # FCPrepare, postinstall handoff
        quiescent = True
        self.assertTrue(quiescent and current == journal['old'] and incoming == journal['new'])
        current, plist = incoming, copy.deepcopy(NEW)
        self.assertTrue(current == journal['new'] and trusted(plist))
        journal['phase'] = 'committed'
        self.assertTrue(journal['phase'] == 'committed' and current == journal['new'] and trusted(plist))

        begin = function(MAINTENANCE, 'static BOOL FCBegin(')
        self.assertIn('NSDictionary *state = repair ? FCTransaction() : nil;', begin)
        self.assertLess(begin.index('FCTransactionResumeAllowed'), begin.index('FCFirstInstallPlistRecoveryAllowed'))
        self.assertLess(begin.index('!repair || !FCFirstInstallPlistRecoveryAllowed'), begin.index('FCWriteCanonicalHelperPlist()'))
        self.assertLess(begin.index('FCWriteCanonicalHelperPlist()'), begin.index('FCWriteTransaction(@"staging"'))
        self.assertIn('![FCSeal(FCInstalledBundle) isEqual:state[@"new"]]', begin)
        pre = (MACOS / 'packaging/installer/repair/preinstall').read_text()
        post = (MACOS / 'packaging/installer/repair/postinstall').read_text()
        self.assertIn('"$guard" beginRepair', pre)
        self.assertNotIn('preflight', pre)
        self.assertNotIn('prepare', pre)
        for earlier, later in (('stageReady', ' arm'), (' arm', ' prepare'),
                               (' prepare', 'bootout'), ('bootout', ' quiescent'),
                               (' quiescent', 'commitInstall'), ('commitInstall', ' verify'),
                               (' verify', 'finishInstall')):
            self.assertLess(post.index(earlier), post.index(later))


if __name__ == '__main__':
    unittest.main()
