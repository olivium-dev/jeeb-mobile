import 'submitted_offer.dart';





abstract class SubmittedOffersRepository {
  
  
  
  Future<List<SubmittedOffer>> listSubmitted();

  
  
  
  Future<bool> withdraw(String offerId);
}
