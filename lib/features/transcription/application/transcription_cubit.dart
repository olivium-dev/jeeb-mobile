import 'package:flutter_bloc/flutter_bloc.dart';

class TranscriptionState {
  final String text;
  final bool isEditing;
  final bool isLoading;

  const TranscriptionState({this.text = '', this.isEditing = false, this.isLoading = false});

  TranscriptionState copyWith({String? text, bool? isEditing, bool? isLoading}) =>
      TranscriptionState(
        text: text ?? this.text,
        isEditing: isEditing ?? this.isEditing,
        isLoading: isLoading ?? this.isLoading,
      );
}

class TranscriptionCubit extends Cubit<TranscriptionState> {
  TranscriptionCubit() : super(const TranscriptionState());

  void setTranscription(String text) => emit(state.copyWith(text: text));

  void startEditing() => emit(state.copyWith(isEditing: true));

  void updateText(String text) => emit(state.copyWith(text: text));

  void confirmEdit() => emit(state.copyWith(isEditing: false));
}
