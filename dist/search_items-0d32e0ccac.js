searchNodes=[{"doc":"","ref":"erqwest.html","title":"erqwest","type":"module"},{"doc":"Used to cancel streaming of a request or response body.","ref":"erqwest.html#cancel/1","title":"erqwest.cancel/1","type":"function"},{"doc":"Close a client and idle connections in its pool. Returns immediately, but the connection pool will not be cleaned up until all in-flight requests for this client have returned. You do not have to call this function, since the client will automatically be cleaned up when it is garbage collected by the VM. Fails with reason badarg if the client has already been closed.","ref":"erqwest.html#close_client/1","title":"erqwest.close_client/1","type":"function"},{"doc":"Convenience wrapper for req/2 .","ref":"erqwest.html#delete/3","title":"erqwest.delete/3","type":"function"},{"doc":"Determines whether a compile-time feature is available. Enable features by adding them to the environment variable ERQWEST_FEATURES (comma separated list) at build time.","ref":"erqwest.html#feature/1","title":"erqwest.feature/1","type":"function"},{"doc":"Complete sending the request body. Awaits the server's reply. Return values are as described for req/2 .","ref":"erqwest.html#finish_send/1","title":"erqwest.finish_send/1","type":"function"},{"doc":"Convenience wrapper for req/2 .","ref":"erqwest.html#get/2","title":"erqwest.get/2","type":"function"},{"doc":"Convenience wrapper for req/2 .","ref":"erqwest.html#get/3","title":"erqwest.get/3","type":"function"},{"doc":"","ref":"erqwest.html#get_client/1","title":"erqwest.get_client/1","type":"function"},{"doc":"Equivalent to make_client(\#{}) .","ref":"erqwest.html#make_client/0","title":"erqwest.make_client/0","type":"function"},{"doc":"Make a new client with its own connection pool. See also start_client/2 .","ref":"erqwest.html#make_client/1","title":"erqwest.make_client/1","type":"function"},{"doc":"Convenience wrapper for req/2 .","ref":"erqwest.html#patch/3","title":"erqwest.patch/3","type":"function"},{"doc":"Convenience wrapper for req/2 .","ref":"erqwest.html#post/3","title":"erqwest.post/3","type":"function"},{"doc":"Convenience wrapper for req/2 .","ref":"erqwest.html#put/3","title":"erqwest.put/3","type":"function"},{"doc":"Equivalent to read(Handle, \#{}) .","ref":"erqwest.html#read/1","title":"erqwest.read/1","type":"function"},{"doc":"Read a chunk of the response body, waiting for at most period ms or until at least length bytes have been read. length defaults to 8 MB if omitted, and period to infinity . Note that more than length bytes can be returned. Returns {more, binary()} if there is more data to be read, and {ok, binary()} once the body is complete.","ref":"erqwest.html#read/2","title":"erqwest.read/2","type":"function"},{"doc":"Make a synchronous request. Fails with reason badarg if any argument is invalid or if the client has already been closed. If you set body to stream , you will get back {handle, handle()} , which you need to pass to send/2 and finish_send/1 to stream the request body. If you set response_body to stream , the body key in resp() be a handle() that you need to pass to read to consume the response body. If you decide not to consume the response body, call cancel/1 .","ref":"erqwest.html#req/2","title":"erqwest.req/2","type":"function"},{"doc":"Stream a chunk of the request body. Returns ok once the chunk has successfully been queued for transmission. Note that due to buffering this does not mean that the chunk has actually been sent. Blocks once the internal buffer is full. Call finish_send/1 once the body is complete. {reply, resp()} is returned if the server chooses to reply before the request body is complete.","ref":"erqwest.html#send/2","title":"erqwest.send/2","type":"function"},{"doc":"Equivalent to start_client(Name, \#{}) .","ref":"erqwest.html#start_client/1","title":"erqwest.start_client/1","type":"function"},{"doc":"Start a client registered under Name . The implementation uses persistent_term and is not intended for clients that will be frequently started and stopped. For such uses see make_client/1 .","ref":"erqwest.html#start_client/2","title":"erqwest.start_client/2","type":"function"},{"doc":"Unregisters and calls close_client/1 on a named client. This is potentially expensive and should not be called frequently, see start_client/2 for more details.","ref":"erqwest.html#stop_client/1","title":"erqwest.stop_client/1","type":"function"},{"doc":"","ref":"erqwest.html#t:client/0","title":"erqwest.client/0","type":"opaque"},{"doc":"","ref":"erqwest.html#t:client_opts/0","title":"erqwest.client_opts/0","type":"type"},{"doc":"","ref":"erqwest.html#t:err/0","title":"erqwest.err/0","type":"type"},{"doc":"","ref":"erqwest.html#t:feature/0","title":"erqwest.feature/0","type":"type"},{"doc":"","ref":"erqwest.html#t:handle/0","title":"erqwest.handle/0","type":"opaque"},{"doc":"","ref":"erqwest.html#t:header/0","title":"erqwest.header/0","type":"type"},{"doc":"","ref":"erqwest.html#t:method/0","title":"erqwest.method/0","type":"type"},{"doc":"","ref":"erqwest.html#t:proxy_config/0","title":"erqwest.proxy_config/0","type":"type"},{"doc":"","ref":"erqwest.html#t:proxy_spec/0","title":"erqwest.proxy_spec/0","type":"type"},{"doc":"","ref":"erqwest.html#t:read_opts/0","title":"erqwest.read_opts/0","type":"type"},{"doc":"","ref":"erqwest.html#t:req_opts/0","title":"erqwest.req_opts/0","type":"type"},{"doc":"","ref":"erqwest.html#t:req_opts_optional/0","title":"erqwest.req_opts_optional/0","type":"type"},{"doc":"","ref":"erqwest.html#t:resp/0","title":"erqwest.resp/0","type":"type"},{"doc":"","ref":"erqwest.html#t:timeout_ms/0","title":"erqwest.timeout_ms/0","type":"type"},{"doc":"","ref":"erqwest_app.html","title":"erqwest_app","type":"module"},{"doc":"","ref":"erqwest_app.html#start/2","title":"erqwest_app.start/2","type":"function"},{"doc":"","ref":"erqwest_app.html#stop/1","title":"erqwest_app.stop/1","type":"function"},{"doc":"","ref":"erqwest_async.html","title":"erqwest_async","type":"module"},{"doc":"Cancel an asynchronous request at any stage. A reply will always still be sent, either {error, \#{code := cancelled}} , another error or a reply depending on the state of the connection. Has no effect if the request has already completed or was already cancelled.","ref":"erqwest_async.html#cancel/1","title":"erqwest_async.cancel/1","type":"function"},{"doc":"Complete sending the request body. The message flow continues as described for req/4 , ie. the next message will be reply or error .","ref":"erqwest_async.html#finish_send/1","title":"erqwest_async.finish_send/1","type":"function"},{"doc":"Read a chunk of the response body, waiting for at most period ms or until at least length bytes have been read. Note that more than length bytes can be returned. length defaults to 8 MB if omitted, and period to infinity . Note that more than length bytes can be returned. Replies with {erqwest_response, Ref, chunk, Data} , {erqwest_response, Ref, fin, Data} or {erqwest_response, Ref, error, erqwest:err()}`. A `fin or error response will be the final message.","ref":"erqwest_async.html#read/2","title":"erqwest_async.read/2","type":"function"},{"doc":"Make an asynchronous request. A Response will be sent to Pid as follows: * If body is stream , and the request was successfully initated, {erqwest_response, Ref, next} . See send/2 and finish_send/1 for how to respond. Alternatively {erqwest_response, Ref, error, erqwest:err()} . * If body is omitted or is of type iodata() , {erqwest_response, Ref, reply, erqwest:resp()} or {erqwest_response, Ref, error, erqwest:err()} . * If response_body is stream , erqwest:resp() will contain a handle which should be passed to read/2 . Alternatively, call cancel/1 if you do not intend to consume the body. An error response is _always_ the final response. If streaming is not used, a single reply is guaranteed. Fails with reason badarg if any argument is invalid or if the client has already been closed.","ref":"erqwest_async.html#req/4","title":"erqwest_async.req/4","type":"function"},{"doc":"Asynchronously stream a chunk of the request body. Replies with {erqwest_response, Ref, next} when the connection is ready to receive more data. Replies with {erqwest_response, Ref, error, erqwest:err()} if something goes wrong, or {erqwest_response, Ref, reply, erqwest:resp()} if the server has already decided to reply. Call finish_send/1 when the request body is complete.","ref":"erqwest_async.html#send/2","title":"erqwest_async.send/2","type":"function"},{"doc":"","ref":"erqwest_async.html#t:handle/0","title":"erqwest_async.handle/0","type":"opaque"},{"doc":"","ref":"erqwest_nif.html","title":"erqwest_nif","type":"module"},{"doc":"","ref":"erqwest_nif.html#cancel/1","title":"erqwest_nif.cancel/1","type":"function"},{"doc":"","ref":"erqwest_nif.html#cancel_stream/1","title":"erqwest_nif.cancel_stream/1","type":"function"},{"doc":"","ref":"erqwest_nif.html#close_client/1","title":"erqwest_nif.close_client/1","type":"function"},{"doc":"","ref":"erqwest_nif.html#feature/1","title":"erqwest_nif.feature/1","type":"function"},{"doc":"","ref":"erqwest_nif.html#finish_send/1","title":"erqwest_nif.finish_send/1","type":"function"},{"doc":"","ref":"erqwest_nif.html#make_client/2","title":"erqwest_nif.make_client/2","type":"function"},{"doc":"","ref":"erqwest_nif.html#read/2","title":"erqwest_nif.read/2","type":"function"},{"doc":"","ref":"erqwest_nif.html#req/4","title":"erqwest_nif.req/4","type":"function"},{"doc":"","ref":"erqwest_nif.html#send/2","title":"erqwest_nif.send/2","type":"function"},{"doc":"","ref":"erqwest_nif.html#start_runtime/1","title":"erqwest_nif.start_runtime/1","type":"function"},{"doc":"","ref":"erqwest_nif.html#stop_runtime/1","title":"erqwest_nif.stop_runtime/1","type":"function"},{"doc":"","ref":"erqwest_runtime.html","title":"erqwest_runtime","type":"module"},{"doc":"","ref":"erqwest_runtime.html#get/0","title":"erqwest_runtime.get/0","type":"function"},{"doc":"","ref":"erqwest_runtime.html#handle_call/3","title":"erqwest_runtime.handle_call/3","type":"function"},{"doc":"","ref":"erqwest_runtime.html#handle_cast/2","title":"erqwest_runtime.handle_cast/2","type":"function"},{"doc":"","ref":"erqwest_runtime.html#handle_info/2","title":"erqwest_runtime.handle_info/2","type":"function"},{"doc":"","ref":"erqwest_runtime.html#init/1","title":"erqwest_runtime.init/1","type":"function"},{"doc":"","ref":"erqwest_runtime.html#start_link/0","title":"erqwest_runtime.start_link/0","type":"function"},{"doc":"","ref":"erqwest_runtime.html#terminate/2","title":"erqwest_runtime.terminate/2","type":"function"},{"doc":"","ref":"erqwest_sup.html","title":"erqwest_sup","type":"module"},{"doc":"","ref":"erqwest_sup.html#init/1","title":"erqwest_sup.init/1","type":"function"},{"doc":"","ref":"erqwest_sup.html#start_link/0","title":"erqwest_sup.start_link/0","type":"function"},{"doc":"An erlang wrapper for reqwest using rustler . Map-based interface inspired by katipo .","ref":"readme.html","title":"erqwest","type":"extras"},{"doc":"HTTP/1.1 and HTTP/2 with connection keepalive/reuse Configurable SSL support, uses system root certificates by default Sync and async interfaces Proxy support Optional cookies support Optional gzip support","ref":"readme.html#features","title":"erqwest - Features","type":"extras"},{"doc":"Erlang/OTP Rust OpenSSL (not required on mac) Or use the provided shell.nix if you have nix installed.","ref":"readme.html#prerequisites","title":"erqwest - Prerequisites","type":"extras"},{"doc":"Start a client ok = application : ensure_started ( erqwest ) , ok = erqwest : start_client ( default ) . This registers a client under the name default . The client maintains an internal connection pool. Synchronous interface No streaming { ok , \#{ status := 200 , body := Body } } = erqwest : get ( default , &lt;&lt; &quot;https://httpbin.org/get&quot; &gt;&gt; ) , { ok , \#{ status := 200 , body := Body1 } } = erqwest : post ( default , &lt;&lt; &quot;https://httpbin.org/post&quot; &gt;&gt; , \#{ body =&gt; &lt;&lt; &quot;data&quot; &gt;&gt; } ) . Stream request body { handle , H } = erqwest : post ( default , &lt;&lt; &quot;https://httpbin.org/post&quot; &gt;&gt; , \#{ body =&gt; stream } ) , ok = erqwest : send ( H , &lt;&lt; &quot;data, &quot; &gt;&gt; ) , ok = erqwest : send ( H , &lt;&lt; &quot;more data.&quot; &gt;&gt; ) , { ok , \#{ body := Body } } = erqwest : finish_send ( H ) . Stream response body { ok , \#{ body := Handle } } = erqwest : get ( default , &lt;&lt; &quot;https://httpbin.org/stream-bytes/1000&quot; &gt;&gt; , \#{ response_body =&gt; stream } ) , ReadAll = fun Self ( ) -&gt; case erqwest : read ( Handle , \#{ length =&gt; 0 } ) of { ok , Data } -&gt; [ Data ] ; { more , Data } -&gt; [ Data | Self ( ) ] end end , 1000 = iolist_size ( ReadAll ( ) ) . Conditionally consume response body { ok , Resp } = erqwest : get ( default , &lt;&lt; &quot;https://httpbin.org/status/200,500&quot; &gt;&gt; , \#{ response_body =&gt; stream } ) , case Resp of \#{ status := 200 , body := Handle } -&gt; { ok , &lt;&lt; &gt;&gt; } = erqwest : read ( Handle ) , \#{ status := BadStatus , body := Handle } -&gt; %% ensures the connection is closed/can be reused immediately erqwest : cancel ( Handle ) , io : format ( &quot;Status is ~p , not interested ~n &quot; , [ BadStatus ] ) end . Asynchronous interface erqwest_async : req ( default , self ( ) , Ref = make_ref ( ) , \#{ method =&gt; get , url =&gt; &lt;&lt; &quot;https://httpbin.org/get&quot; &gt;&gt; } ) , receive { erqwest_response , Ref , reply , \#{ body := Body } } -&gt; Body end . See the docs for more details and and the test suite for more examples.","ref":"readme.html#usage","title":"erqwest - Usage","type":"extras"},{"doc":"","ref":"readme.html#docs","title":"erqwest - Docs","type":"extras"},{"doc":"","ref":"readme.html#benchmarks","title":"erqwest - Benchmarks","type":"extras"},{"doc":"Apache License Version 2.0, January 2004 http://www.apache.org/licenses/ TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION 1. Definitions. &quot;License&quot; shall mean the terms and conditions for use, reproduction, and distribution as defined by Sections 1 through 9 of this document. &quot;Licensor&quot; shall mean the copyright owner or entity authorized by the copyright owner that is granting the License. &quot;Legal Entity&quot; shall mean the union of the acting entity and all other entities that control, are controlled by, or are under common control with that entity. For the purposes of this definition, &quot;control&quot; means (i) the power, direct or indirect, to cause the direction or management of such entity, whether by contract or otherwise, or (ii) ownership of fifty percent (50%) or more of the outstanding shares, or (iii) beneficial ownership of such entity. &quot;You&quot; (or &quot;Your&quot;) shall mean an individual or Legal Entity exercising permissions granted by this License. &quot;Source&quot; form shall mean the preferred form for making modifications, including but not limited to software source code, documentation source, and configuration files. &quot;Object&quot; form shall mean any form resulting from mechanical transformation or translation of a Source form, including but not limited to compiled object code, generated documentation, and conversions to other media types. &quot;Work&quot; shall mean the work of authorship, whether in Source or Object form, made available under the License, as indicated by a copyright notice that is included in or attached to the work (an example is provided in the Appendix below). &quot;Derivative Works&quot; shall mean any work, whether in Source or Object form, that is based on (or derived from) the Work and for which the editorial revisions, annotations, elaborations, or other modifications represent, as a whole, an original work of authorship. For the purposes of this License, Derivative Works shall not include works that remain separable from, or merely link (or bind by name) to the interfaces of, the Work and Derivative Works thereof. &quot;Contribution&quot; shall mean any work of authorship, including the original version of the Work and any modifications or additions to that Work or Derivative Works thereof, that is intentionally submitted to Licensor for inclusion in the Work by the copyright owner or by an individual or Legal Entity authorized to submit on behalf of the copyright owner. For the purposes of this definition, &quot;submitted&quot; means any form of electronic, verbal, or written communication sent to the Licensor or its representatives, including but not limited to communication on electronic mailing lists, source code control systems, and issue tracking systems that are managed by, or on behalf of, the Licensor for the purpose of discussing and improving the Work, but excluding communication that is conspicuously marked or otherwise designated in writing by the copyright owner as &quot;Not a Contribution.&quot; &quot;Contributor&quot; shall mean Licensor and any individual or Legal Entity on behalf of whom a Contribution has been received by Licensor and subsequently incorporated within the Work. 2. Grant of Copyright License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable copyright license to reproduce, prepare Derivative Works of, publicly display, publicly perform, sublicense, and distribute the Work and such Derivative Works in Source or Object form. 3. Grant of Patent License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable (except as stated in this section) patent license to make, have made, use, offer to sell, sell, import, and otherwise transfer the Work, where such license applies only to those patent claims licensable by such Contributor that are necessarily infringed by their Contribution(s) alone or by combination of their Contribution(s) with the Work to which such Contribution(s) was submitted. If You institute patent litigation against any entity (including a cross-claim or counterclaim in a lawsuit) alleging that the Work or a Contribution incorporated within the Work constitutes direct or contributory patent infringement, then any patent licenses granted to You under this License for that Work shall terminate as of the date such litigation is filed. 4. Redistribution. You may reproduce and distribute copies of the Work or Derivative Works thereof in any medium, with or without modifications, and in Source or Object form, provided that You meet the following conditions: (a) You must give any other recipients of the Work or Derivative Works a copy of this License; and (b) You must cause any modified files to carry prominent notices stating that You changed the files; and (c) You must retain, in the Source form of any Derivative Works that You distribute, all copyright, patent, trademark, and attribution notices from the Source form of the Work, excluding those notices that do not pertain to any part of the Derivative Works; and (d) If the Work includes a &quot;NOTICE&quot; text file as part of its distribution, then any Derivative Works that You distribute must include a readable copy of the attribution notices contained within such NOTICE file, excluding those notices that do not pertain to any part of the Derivative Works, in at least one of the following places: within a NOTICE text file distributed as part of the Derivative Works; within the Source form or documentation, if provided along with the Derivative Works; or, within a display generated by the Derivative Works, if and wherever such third-party notices normally appear. The contents of the NOTICE file are for informational purposes only and do not modify the License. You may add Your own attribution notices within Derivative Works that You distribute, alongside or as an addendum to the NOTICE text from the Work, provided that such additional attribution notices cannot be construed as modifying the License. You may add Your own copyright statement to Your modifications and may provide additional or different license terms and conditions for use, reproduction, or distribution of Your modifications, or for any such Derivative Works as a whole, provided Your use, reproduction, and distribution of the Work otherwise complies with the conditions stated in this License. 5. Submission of Contributions. Unless You explicitly state otherwise, any Contribution intentionally submitted for inclusion in the Work by You to the Licensor shall be under the terms and conditions of this License, without any additional terms or conditions. Notwithstanding the above, nothing herein shall supersede or modify the terms of any separate license agreement you may have executed with Licensor regarding such Contributions. 6. Trademarks. This License does not grant permission to use the trade names, trademarks, service marks, or product names of the Licensor, except as required for reasonable and customary use in describing the origin of the Work and reproducing the content of the NOTICE file. 7. Disclaimer of Warranty. Unless required by applicable law or agreed to in writing, Licensor provides the Work (and each Contributor provides its Contributions) on an &quot;AS IS&quot; BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied, including, without limitation, any warranties or conditions of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE. You are solely responsible for determining the appropriateness of using or redistributing the Work and assume any risks associated with Your exercise of permissions under this License. 8. Limitation of Liability. In no event and under no legal theory, whether in tort (including negligence), contract, or otherwise, unless required by applicable law (such as deliberate and grossly negligent acts) or agreed to in writing, shall any Contributor be liable to You for damages, including any direct, indirect, special, incidental, or consequential damages of any character arising as a result of this License or out of the use or inability to use the Work (including but not limited to damages for loss of goodwill, work stoppage, computer failure or malfunction, or any and all other commercial damages or losses), even if such Contributor has been advised of the possibility of such damages. 9. Accepting Warranty or Additional Liability. While redistributing the Work or Derivative Works thereof, You may choose to offer, and charge a fee for, acceptance of support, warranty, indemnity, or other liability obligations and/or rights consistent with this License. However, in accepting such obligations, You may act only on Your own behalf and on Your sole responsibility, not on behalf of any other Contributor, and only if You agree to indemnify, defend, and hold each Contributor harmless for any liability incurred by, or claims asserted against, such Contributor by reason of your accepting any such warranty or additional liability. END OF TERMS AND CONDITIONS Copyright 2021, David &lt;dlesl@users.noreply.github.com&gt;. Licensed under the Apache License, Version 2.0 (the &quot;License&quot;); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an &quot;AS IS&quot; BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.","ref":"license.html","title":"LICENSE","type":"extras"}]