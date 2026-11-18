// The peer of UnreadablePeerTests.m: stands in for the daemon. It runs from a directory the test makes unreadable
// right after exec, connects back over the test's anonymous XPC listener (whose port it inherits through
// mach_ports_register) and answers every request, like the daemon answers the app.
#include <dispatch/dispatch.h>
#include <mach/mach.h>
#include <unistd.h>
#include <xpc/xpc.h>

xpc_endpoint_t xpc_endpoint_create_mach_port_4sim(mach_port_t port);

int main(void) {
    mach_port_t *ports = NULL;
    mach_msg_type_number_t count = 0;
    if (mach_ports_lookup(mach_task_self(), &ports, &count) || count < 1 || !MACH_PORT_VALID(ports[0])) return 2;
    // Give the test time to take the directory away first: the connection then exists only while it is unreadable.
    sleep(1);
    xpc_connection_t connection = xpc_connection_create_from_endpoint(xpc_endpoint_create_mach_port_4sim(ports[0]));
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        if (xpc_get_type(event) == XPC_TYPE_DICTIONARY) {
            xpc_object_t reply = xpc_dictionary_create_reply(event);
            if (!reply) return;
            xpc_dictionary_set_string(reply, "code", "ok");
            xpc_dictionary_set_int64(reply, "protocol", 1);
            xpc_connection_send_message(connection, reply);
        } else if (event == XPC_ERROR_CONNECTION_INVALID) {
            _exit(0);
        }
    });
    xpc_connection_resume(connection);
    xpc_object_t hello = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(hello, "method", "hello");
    xpc_connection_send_message(connection, hello);
    dispatch_main();
}
