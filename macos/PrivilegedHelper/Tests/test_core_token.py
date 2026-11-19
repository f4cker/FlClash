import re
import subprocess
import tempfile
import unittest
from pathlib import Path


MACOS = Path(__file__).resolve().parents[2]
SUPERVISOR = (MACOS / 'PrivilegedHelper/Supervisor.m').read_text()


def function(declaration):
    start = SUPERVISOR.index(declaration)
    opening = SUPERVISOR.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (SUPERVISOR[end] == '{') - (SUPERVISOR[end] == '}')
        end += 1
    return SUPERVISOR[start:end]


class CoreTokenTests(unittest.TestCase):
    """The Core's audit token reaches only the owner, on the reply to the start that made it the owner."""

    def test_only_a_successful_start_carries_the_token(self):
        source = '#import <Foundation/Foundation.h>\n#import <assert.h>\n' + function(
            'static BOOL FCRepliesWithCoreToken') + r'''
int main(void) {
    assert(FCRepliesWithCoreToken(@"start", @"ok"));
    for (NSString *action in @[@"hello", @"exit", @"stop", @"send", @"receive", @"bogus"])
        for (NSString *code in @[@"ok", @"wrongOwner", @"sessionBusy"]) assert(!FCRepliesWithCoreToken(action, code));
    for (NSString *code in @[@"wrongOwner", @"sessionBusy", @"incompatible", @"relayFailed", @"selfCheckFailed"])
        assert(!FCRepliesWithCoreToken(@"start", code));
    return 0;
}
'''
        with tempfile.TemporaryDirectory(prefix='flash-core-token-') as scratch:
            binary = Path(scratch) / 'token'
            (Path(scratch) / 'token.m').write_text(source)
            subprocess.run(['clang', '-fobjc-arc', '-Werror', str(Path(scratch) / 'token.m'),
                            '-framework', 'Foundation', '-o', str(binary)], check=True, capture_output=True, text=True)
            subprocess.run([str(binary)], check=True, capture_output=True, text=True, timeout=10)

    def test_replies_set_the_token_from_the_argument_alone(self):
        reply = function('- (void)reply:(xpc_object_t)request')
        self.assertEqual(reply.count('coreAuditToken'), 1)
        self.assertIn('if (coreToken) xpc_dictionary_set_data(reply, "coreAuditToken"', reply)
        self.assertNotIn('self.coreToken', reply)
        # Only handle:'s reply may carry the token, and only by FCRepliesWithCoreToken; every other reply (the
        # incompatible-request one and those of a held receive) passes nil.
        calls = re.findall(r'\[self reply:\w+[^;]*;', SUPERVISOR, re.S)
        tokened = [call for call in calls if 'coreToken:nil' not in call]
        self.assertGreaterEqual(len(calls), 2)
        self.assertEqual(len(tokened), 1)
        self.assertIn('coreToken:FCRepliesWithCoreToken(action, code) ? self.coreToken : nil', tokened[0])
        self.assertIn('[self reply:request', tokened[0])


if __name__ == '__main__':
    unittest.main()
