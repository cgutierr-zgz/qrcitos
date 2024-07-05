import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await HydratedStorage.build(
      storageDirectory: HydratedStorage.webStorageDirectory);
  HydratedBloc.storage = storage;
  runApp(BlocProvider(create: (context) => QRCubit(), child: const App()));
}

class QRCubit extends HydratedCubit<List<QrCreatorData>> {
  QRCubit() : super([]);

  void addQR(QrCreatorData qrData) =>
      emit([...state, qrData.copyWith(id: state.length)]);

  void updateQR(QrCreatorData oldQrData, QrCreatorData newQrData) {
    emit(state
        .map((data) => data.id == oldQrData.id ? newQrData : data)
        .toList());
  }

  void removeQR(QrCreatorData qrData) {
    emit(state.where((data) => data.id != qrData.id).toList());
  }

  void removeAll() => emit([]);

  @override
  List<QrCreatorData> fromJson(Map<String, dynamic> json) {
    return (json['qrList'] as List)
        .map((item) => QrCreatorData.fromJson(item))
        .toList();
  }

  @override
  Map<String, dynamic> toJson(List<QrCreatorData> state) {
    return {'qrList': state.map((qrData) => qrData.toJson()).toList()};
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BlocBuilder<QRCubit, List<QrCreatorData>>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('QR Code Creator')),
            body: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    context.read<QRCubit>().addQR(QrCreatorData());
                  },
                  child: const Text('Add QR Creator'),
                ),
                Expanded(
                  child: ListView(
                    children: state
                        .map((qrData) => Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: QRCreator(qrData: qrData),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class QrCreatorData {
  QrCreatorData({
    this.id,
    this.text = '',
    this.typeNumber = 6,
    this.errorCorrectLevel = QrErrorCorrectLevel.H,
  });

  final int? id;
  final String text;
  final int typeNumber;
  final int errorCorrectLevel;

  QrCreatorData copyWith({
    int? id,
    String? text,
    int? typeNumber,
    int? errorCorrectLevel,
  }) {
    return QrCreatorData(
      id: id ?? this.id,
      text: text ?? this.text,
      typeNumber: typeNumber ?? this.typeNumber,
      errorCorrectLevel: errorCorrectLevel ?? this.errorCorrectLevel,
    );
  }

  factory QrCreatorData.fromJson(Map<String, dynamic> json) {
    return QrCreatorData(
      id: json['id'],
      text: json['text'],
      typeNumber: json['typeNumber'],
      errorCorrectLevel: json['errorCorrectLevel'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'typeNumber': typeNumber,
      'errorCorrectLevel': errorCorrectLevel,
    };
  }
}

class QRCreator extends StatefulWidget {
  const QRCreator({super.key, required this.qrData});

  final QrCreatorData qrData;

  @override
  State<QRCreator> createState() => _QRCreatorState();
}

class _QRCreatorState extends State<QRCreator> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.qrData.text);
    controller.addListener(() {
      final updatedQRData = widget.qrData.copyWith(text: controller.text);
      context.read<QRCubit>().updateQR(widget.qrData, updatedQRData);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Enter text'),
              ),
              Row(
                children: [
                  DropdownButton<int>(
                    value: widget.qrData.typeNumber,
                    items: List.generate(
                        40,
                        (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            )),
                    onChanged: (value) {
                      setState(() {
                        final updatedQRData =
                            widget.qrData.copyWith(typeNumber: value as int);
                        context
                            .read<QRCubit>()
                            .updateQR(widget.qrData, updatedQRData);
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: widget.qrData.errorCorrectLevel,
                    items: QrErrorCorrectLevel.levels.map((level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Text(QrErrorCorrectLevel.getName(level)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        final updatedQRData = widget.qrData
                            .copyWith(errorCorrectLevel: value as int);
                        context
                            .read<QRCubit>()
                            .updateQR(widget.qrData, updatedQRData);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Builder(builder: (context) {
          QrImage qr;

          try {
            qr = QrImage(
              QrCode(widget.qrData.typeNumber, widget.qrData.errorCorrectLevel)
                ..addData(controller.text),
            );

            return InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('QR Code'),
                      content: SizedBox.square(
                        dimension: 500,
                        child: PrettyQrView(
                          qrImage: qr,
                        ),
                      ),
                    );
                  },
                );
              },
              child: SizedBox.square(
                dimension: 300,
                child: PrettyQrView(
                  qrImage: qr,
                  // PrettyQrSmoothSymbol - PrettyQrRoundedSymbol
                  //decoration: PrettyQrDecoration(
                  //  shape: PrettyQrSmoothSymbol(
                  //      // color: _PrettyQrSettings.kDefaultQrDecorationBrush,
                  //      ),
                  //  //image: _PrettyQrSettings.kDefaultQrDecorationImage,
                  //),
                ),
              ),
            );
          } catch (e) {
            final message = e is InputTooLongException
                ? '${e.message} for type ${widget.qrData.typeNumber} a QR code.'
                : e.toString();
            return Tooltip(
              message: message,
              child: const Icon(
                Icons.error,
              ),
            );
          }
        }),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => context.read<QRCubit>().removeQR(widget.qrData),
        ),
      ],
    );
  }
}
