import '../domain/sos_draft.dart';

class LocalSosRepository extends SosRepository {
  @override
  Future<ClientSosRequest> submit(SosDraft draft) async {
    if (!draft.isValid) throw ArgumentError('invalid_sos');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return ClientSosRequest(
      id: draft.requestId ?? newSosRequestId(),
      district: draft.districtCourt,
      status: ClientSosStatus.open,
      isDemo: true,
    );
  }
}
