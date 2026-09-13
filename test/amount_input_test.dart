import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/features/bookkeeping/application/amount_input.dart';

void main() {
  group('AmountInput 纯数字（保持原有契约）', () {
    test('空值显示 0.00 且不可保存', () {
      const input = AmountInput();
      expect(input.displayValue, '0.00');
      expect(input.label, '');
      expect(input.amount, isNull);
      expect(input.isValid, isFalse);
      expect(input.hasOperator, isFalse);
    });

    test('逐位输入补足两位小数', () {
      final input = const AmountInput().enter('3').enter('6');
      expect(input.value, '36');
      expect(input.displayValue, '36.00');
      expect(input.amount, 36);
      expect(input.label, '36.00');
      expect(input.isValid, isTrue);
      expect(input.hasOperator, isFalse);
    });

    test('前导 0 会被替换而不是拼接', () {
      expect(const AmountInput().enter('0').enter('0').value, '0');
      expect(const AmountInput().enter('0').enter('5').value, '5');
    });

    test('小数点最多两位，且同一数字段只能有一个小数点', () {
      final input = const AmountInput()
          .enter('1')
          .enter('.')
          .enter('5')
          .enter('5')
          .enter('5');
      expect(input.value, '1.55');
      expect(const AmountInput().enter('1').enter('.').enter('.').value, '1.');
      expect(const AmountInput().enter('.').value, '0.');
    });

    test('单个数字段最多 10 位', () {
      var input = const AmountInput();
      for (var index = 0; index < 12; index++) {
        input = input.enter('9');
      }
      expect(input.value, '9999999999');
    });

    test('退格删除最后一个字符', () {
      expect(const AmountInput('36').backspace().value, '3');
      expect(const AmountInput().backspace().value, '');
    });
  });

  group('AmountInput 计算器表达式', () {
    test('乘法表达式按预览结果取整到分', () {
      final input = const AmountInput()
          .enter('1')
          .enter('0')
          .enter('0')
          .enter('*')
          .enter('2');
      expect(input.value, '100*2');
      expect(input.hasOperator, isTrue);
      expect(input.label, '100*2');
      expect(input.amount, 200);
      expect(input.displayValue, '200.00');
      expect(input.isValid, isTrue);
    });

    test('乘除优先于加减', () {
      expect(const AmountInput('2+3*4').amount, 14);
      expect(const AmountInput('2*3+4').amount, 10);
      expect(const AmountInput('20-4/2').amount, 18);
    });

    test('结果四舍五入到分，避免浮点噪声', () {
      expect(const AmountInput('10/3').amount, 3.33);
      expect(const AmountInput('0.1+0.2').amount, 0.3);
      expect(const AmountInput('10/4').amount, 2.5);
    });

    test('除零与负数结果都不允许保存', () {
      expect(const AmountInput('10/0').amount, isNull);
      expect(const AmountInput('10/0').isValid, isFalse);
      expect(const AmountInput('5-10').amount, -5);
      expect(const AmountInput('5-10').isValid, isFalse);
    });

    test('未输完的表达式不完整、不能保存，但仍显示运行结果', () {
      const pending = AmountInput('100+');
      expect(pending.isComplete, isFalse);
      expect(pending.isValid, isFalse);
      expect(pending.amount, 100);
      expect(pending.displayValue, '100.00');
    });

    test('不允许前导运算符，连续运算符会替换而不是叠加', () {
      expect(const AmountInput().enter('+').value, '');
      expect(const AmountInput('100+').enter('-').value, '100-');
      expect(const AmountInput('100*').enter('/').value, '100/');
      expect(const AmountInput('100.').enter('+').value, '100.');
    });

    test('每个数字段独立限制小数位', () {
      final input = const AmountInput('1.5+2.25');
      expect(input.amount, 3.75);
      expect(
        const AmountInput('1.55').enter('+').enter('2').enter('.')
            .enter('2')
            .enter('5')
            .enter('0')
            .value,
        '1.55+2.25',
      );
    });

    test('运算符之后可以继续输入数字和小数点', () {
      expect(const AmountInput('100+').enter('5').value, '100+5');
      expect(const AmountInput('100+').enter('.').value, '100+0.');
    });
  });
}
